import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'nabeeh_colors.dart';

// =====================================================================
// إعدادات Azure Speech Services — عدّليها بمفاتيحك من Azure Portal
// =====================================================================
const String _kAzureSpeechKey = '9lz61KqwP59MlMj2RS7yTugTWEkRDXBrZ49UDKnxCPAA05XOTpNQJQQJ99CHACI8hq2XJ3w3AAAYACOGYzD0';
const String _kAzureRegion = 'switzerlandnorth'; // مثلاً: uaenorth, westeurope ...
const String _kSttLanguageCode = 'ar-SA'; // أو ar-EG, ar-AE حسب اللهجة
const String _kTtsLanguageCode = 'ar-SA';
const String _kTtsVoiceName = 'ar-SA-ZariyahNeural'; // صوت أنثى سعودي (Neural)

class SttTtsScreen extends StatefulWidget {
  const SttTtsScreen({super.key});

  @override
  State<SttTtsScreen> createState() => _SttTtsScreenState();
}

class _SttTtsScreenState extends State<SttTtsScreen>
    with SingleTickerProviderStateMixin {
  bool _isSttMode = true;
  bool _isRecording = false;
  bool _isSpeaking = false;
  String _textContent = '';
  Timer? _speakingTimer;
  final FocusNode _textFocusNode = FocusNode();
  late TextEditingController _ttsController;

  double _amplitude = 0.0;

  FlutterSoundRecorder? _recorder;
  StreamSubscription<RecordingDisposition>? _recorderSubscription;
  late AnimationController _waveController;

  // ------------------- إضافات خاصة بـ Azure STT (Streaming) -------------------
  WebSocketChannel? _sttSocket;
  StreamSubscription? _audioSubscription;
  StreamController<Uint8List>? _micStreamController;

  // ------------------- إضافات خاصة بـ Azure TTS -------------------
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _ttsController = TextEditingController();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
  }

  @override
  void dispose() {
    _speakingTimer?.cancel();
    _recorderSubscription?.cancel();
    _audioSubscription?.cancel();
    _micStreamController?.close();
    _sttSocket?.sink.close();
    _recorder?.closeRecorder();
    _audioPlayer.dispose();
    _textFocusNode.dispose();
    _ttsController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _switchMode(bool sttMode) {
    setState(() {
      _isSttMode = sttMode;
      _textContent = '';
      _isRecording = false;
      _isSpeaking = false;
      _ttsController.clear();
      _stopListening();
    });
    _speakingTimer?.cancel();
    if (!sttMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _textFocusNode.requestFocus();
      });
    }
  }

  void _toggleRecording() async {
    if (_isRecording) {
      await _stopListening();
    } else {
      setState(() => _textContent = '');
      await _startListening();
    }
    setState(() => _isRecording = !_isRecording);
  }

  // =====================================================================
  // Real-time Speech-to-Text عبر Azure Speech-to-Text REST + استخدام ملف
  // مسجَّل قصير كبديل مبسّط عن WebSocket المباشر (أسهل صيانة لمشروع تخرج)
  // =====================================================================
  //
  // ملاحظة تصميمية: Azure يوفر بروتوكول WebSocket خام معقد التنسيق (custom
  // binary framing)، وأيضاً Speech SDK رسمي (لا يوجد له حزمة Flutter رسمية
  // مستقرة حالياً). لذلك نعتمد هنا على نمط "تسجيل قصير قطع صوت متتالية كل
  // ~2 ثانية وإرسالها لـ REST API الخاص بالنسخ السريع (Fast Transcription)"،
  // وهو حل عملي يعطي إحساساً قريباً من real-time بدون تعقيد WebSocket.
  Timer? _chunkTimer;
  String _accumulatedTranscript = '';

  Future<void> _startListening() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('Microphone permission denied');
      _showEmptyTextWarning('صلاحية الوصول للمايكروفون مطلوبة');
      return;
    }

    _accumulatedTranscript = '';

    try {
      await _startNewChunkRecording();

      // كل ثانيتين: نوقف القطعة الحالية، نرسلها للتفريغ، ونبدأ قطعة جديدة
      _chunkTimer =
          Timer.periodic(const Duration(seconds: 2), (_) async {
        await _processCurrentChunk();
        if (_isRecording) {
          await _startNewChunkRecording();
        }
      });
    } catch (e) {
      debugPrint('RECORDER ERROR: $e');
      _showEmptyTextWarning('تعذر بدء التسجيل');
    }
  }

  String? _currentChunkPath;

  Future<void> _startNewChunkRecording() async {
    final dir = await getTemporaryDirectory();
    _currentChunkPath =
        '${dir.path}/chunk_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder!.startRecorder(
      toFile: _currentChunkPath,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
      numChannels: 1,
    );

    _recorderSubscription = _recorder!.onProgress?.listen((event) {
      if (!mounted) return;
      final db = event.decibels ?? -40.0;
      double normalized = ((db + 40) / 40).clamp(0.0, 1.0);
      double smooth = _amplitude + (normalized - _amplitude) * 0.3;
      setState(() => _amplitude = smooth);
    });
  }

  Future<void> _processCurrentChunk() async {
    if (_recorder == null || _currentChunkPath == null) return;
    final path = await _recorder!.stopRecorder();
    if (path == null) return;

    final file = File(path);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    if (bytes.length < 2000) return; // قطعة صغيرة جداً / صامتة، تجاهليها

    await _transcribeChunk(bytes);
  }

  Future<void> _transcribeChunk(Uint8List audioBytes) async {
    final url = Uri.parse(
      'https://$_kAzureRegion.stt.speech.microsoft.com/speech/recognition/'
      'conversation/cognitiveservices/v1?language=$_kSttLanguageCode&format=simple',
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Ocp-Apim-Subscription-Key': _kAzureSpeechKey,
          'Content-Type':
              'audio/wav; codecs=audio/pcm; samplerate=16000',
          'Accept': 'application/json',
        },
        body: audioBytes,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayText = data['DisplayText'] as String?;
        if (displayText != null && displayText.trim().isNotEmpty) {
          _accumulatedTranscript =
              '$_accumulatedTranscript $displayText'.trim();
          if (mounted) {
            setState(() => _textContent = _accumulatedTranscript);
          }
        }
      } else {
        debugPrint('Azure STT Error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Azure STT Exception: $e');
    }
  }

  Future<void> _stopListening() async {
    _chunkTimer?.cancel();
    _chunkTimer = null;
    _recorderSubscription?.cancel();
    _recorderSubscription = null;

    if (_recorder != null && _recorder!.isRecording) {
      await _processCurrentChunk();
    }

    if (mounted) setState(() => _amplitude = 0.0);
  }

  void _clearText() {
    setState(() {
      _textContent = '';
      _isRecording = false;
      _ttsController.clear();
      _stopListening();
    });
  }

  // --- Shared warning SnackBar style (red ribbon) for empty-text actions ---
  void _showEmptyTextWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        elevation: 0,
        backgroundColor: const Color(0xFFFFEBEB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFFF4D4D), width: 1.2),
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: Color(0xFFD32F2F),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD32F2F),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyText() {
    if (_textContent.trim().isEmpty) {
      _showEmptyTextWarning('لا يوجد نص لنسخه حالياً');
      return;
    }

    Clipboard.setData(ClipboardData(text: _textContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ النص'),
        duration: Duration(seconds: 1),
        backgroundColor: NabeehColors.dark,
      ),
    );
  }

  // =====================================================================
  // Text-to-Speech (Azure Speech Services REST API)
  // =====================================================================
  void _speakText() async {
    if (_textContent.trim().isEmpty) {
      _showEmptyTextWarning('لا يوجد نص للنطق حالياً');
      return;
    }

    if (_isSpeaking) {
      await _audioPlayer.stop();
      _speakingTimer?.cancel();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }

    setState(() => _isSpeaking = true);

    final url = Uri.parse(
      'https://$_kAzureRegion.tts.speech.microsoft.com/cognitiveservices/v1',
    );

    final ssml =
        '''<speak version='1.0' xml:lang='$_kTtsLanguageCode'>
  <voice xml:lang='$_kTtsLanguageCode' name='$_kTtsVoiceName'>
    ${_escapeXml(_textContent)}
  </voice>
</speak>''';

    try {
      final response = await http.post(
        url,
        headers: {
          'Ocp-Apim-Subscription-Key': _kAzureSpeechKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
        },
        body: utf8.encode(ssml),
      );

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/tts_output.mp3');
        await file.writeAsBytes(response.bodyBytes);

        await _audioPlayer.play(DeviceFileSource(file.path));
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _isSpeaking = false);
        });
      } else {
        debugPrint('Azure TTS Error: ${response.statusCode} ${response.body}');
        if (mounted) {
          setState(() => _isSpeaking = false);
          _showEmptyTextWarning('تعذر تحويل النص إلى صوت');
        }
      }
    } catch (e) {
      debugPrint('Azure TTS Exception: $e');
      if (mounted) {
        setState(() => _isSpeaking = false);
        _showEmptyTextWarning('تحقق من الاتصال بالإنترنت');
      }
    }
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  void _insertPhrase(String phrase) {
    setState(() {
      if (_textContent.isEmpty) {
        _textContent = phrase;
      } else {
        _textContent = '$_textContent $phrase';
      }
      _ttsController.text = _textContent;
    });
  }

  String _getHeadingFromText(String text) {
    final words = text.trim().split(' ');
    if (words.length <= 3) return text;
    return '${words.take(3).join(' ')}...';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFDDEEF8), Color(0xFFF2F9FE), Colors.white],
              stops: [0.0, 0.35, 0.6],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _buildHeader(context),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildModeSwitcher(),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                    child: AnimatedSwitcher(
                      duration: 250.ms,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        fit: StackFit.expand,
                        children: [
                          ...previousChildren,
                          if (currentChild case final child?) child,
                        ],
                      ),
                      child: _isSttMode
                          ? KeyedSubtree(
                              key: const ValueKey('stt'),
                              child: _buildSttView(),
                            )
                          : KeyedSubtree(
                              key: const ValueKey('tts'),
                              child: _buildTtsView(),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 64, bottom: 20, right: 20, left: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(
                      color: const Color(0xFF181059),
                      width: 1.5,
                    ),
                  ),
                  child: const Directionality(
                    textDirection: TextDirection.ltr,
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF181059),
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'التواصل',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181059),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    NabeehColors.darkNavy,
                    NabeehColors.darkNavy,
                    NabeehColors.lightBlue,
                  ],
                  stops: [0.09, 0.30, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  'assets/images/icon_signLan.png',
                  color: NabeehColors.background,
                  colorBlendMode: BlendMode.srcIn,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Padding(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: NabeehColors.slate50,
          border: Border.all(color: NabeehColors.slate100),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildModeTab(
                title: 'استماع',
                icon: LucideIcons.mic,
                isSelected: _isSttMode,
                onTap: () => _switchMode(true),
              ),
            ),
            Expanded(
              child: _buildModeTab(
                title: 'تحدث',
                icon: LucideIcons.volume2,
                isSelected: !_isSttMode,
                onTap: () => _switchMode(false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF181059), Color(0xFF1773CF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF181059).withValues(alpha: 0.3),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : NabeehColors.slate400,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : NabeehColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSttView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            height: 340,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: NabeehColors.slate100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  if (_textContent.isEmpty) ...[
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isRecording
                                  ? 'ابدأ التحدث الآن...'
                                  : 'اضغط على المايك للبدء',
                              style: const TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                                color: NabeehColors.slate500,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isRecording
                                  ? 'سيظهر النص الملتقط هنا مباشرة'
                                  : 'سيظهر النص الملتقط هنا عند البدء بالاستماع',
                              style: const TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                                color: NabeehColors.slate400,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    if (_isRecording) ...[
                      _buildRecordingWaveform(),
                      const SizedBox(height: 16),
                      const Divider(color: NabeehColors.slate100),
                      const SizedBox(height: 16),
                      Text(
                        _getHeadingFromText(_textContent),
                        style: const TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: NabeehColors.dark,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Text(
                        _getHeadingFromText(_textContent),
                        style: const TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: NabeehColors.dark,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildToolsIcon(LucideIcons.copy, onTap: _copyText),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _toggleRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? NabeehColors.lightBlue.withValues(alpha: 0.1)
                    : NabeehColors.slate200.withValues(alpha: 0.5),
                boxShadow: _isRecording
                    ? [
                        BoxShadow(
                          color: NabeehColors.lightBlue.withValues(alpha: 0.2),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Icon(
                  _isRecording ? LucideIcons.mic : LucideIcons.micOff,
                  size: 50,
                  color:
                      _isRecording ? NabeehColors.lightBlue : NabeehColors.slate400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTtsView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            height: 340,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: NabeehColors.slate100),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ttsController,
                      focusNode: _textFocusNode,
                      maxLines: null,
                      expands: true,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      onChanged: (value) => setState(() => _textContent = value),
                      decoration: const InputDecoration(
                        hintText: 'اكتب ما تريد قوله هنا...',
                        hintStyle: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          color: NabeehColors.slate400,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      cursorColor: NabeehColors.darkBlue,
                      style: const TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        height: 1.6,
                      ),
                    ),
                  ),
                  if (_textContent.trim().isEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          'مرحبا',
                          'كيف حالك؟',
                          'أنا بحاجة لمساعدة',
                          'شكراً لك',
                        ]
                            .map(
                              (phrase) => Padding(
                                padding:
                                    const EdgeInsetsDirectional.only(start: 8),
                                child: _buildPhrase(phrase),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Divider(color: NabeehColors.slate100),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildToolsIcon(LucideIcons.x, onTap: _clearText),
                        ],
                      ),
                      Text(
                        '${_textContent.length} أحرف',
                        style: const TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: NabeehColors.slate400,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _speakText,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isSpeaking
                    ? NabeehColors.lightBlue.withValues(alpha: 0.1)
                    : NabeehColors.slate200.withValues(alpha: 0.5),
                boxShadow: _isSpeaking
                    ? [
                        BoxShadow(
                          color: NabeehColors.lightBlue.withValues(alpha: 0.2),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Icon(
                  LucideIcons.volume2,
                  size: 50,
                  color:
                      _isSpeaking ? NabeehColors.lightBlue : NabeehColors.slate400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRecordingWaveform() {
    return SizedBox(
      height: 90,
      child: _buildWaveBars(isActive: _isRecording),
    );
  }

  Widget _buildWaveBars({required bool isActive}) {
    return SizedBox(
      height: 60,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(15, (index) {
              final offset = index * 0.4;
              final baseWave =
                  (math.sin((_waveController.value * 2 * math.pi) + offset) +
                      1) /
                  2;
              final liveLevel = isActive ? (0.35 + (_amplitude * 0.65)) : 0.0;
              final barHeight = 10 + (baseWave * 50 * liveLevel);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 9,
                height: barHeight,
                decoration: BoxDecoration(
                  color: isActive
                      ? NabeehColors.lightBlue.withValues(alpha: 0.8)
                      : NabeehColors.slate300,
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildPhrase(String phrase) {
    return GestureDetector(
      onTap: () => _insertPhrase(phrase),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: NabeehColors.slate50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NabeehColors.slate100),
          boxShadow: [
            BoxShadow(
              color: NabeehColors.dark.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          phrase,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: NabeehColors.slate500,
          ),
        ),
      ),
    );
  }

  Widget _buildToolsIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: NabeehColors.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NabeehColors.slate100),
          boxShadow: [
            BoxShadow(
              color: NabeehColors.dark.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: NabeehColors.slate400),
      ),
    );
  }
}
