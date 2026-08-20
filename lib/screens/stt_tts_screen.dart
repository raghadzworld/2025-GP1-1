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
import 'package:web_socket_channel/io.dart';
import 'nabeeh_colors.dart';

// =====================================================================
// إعدادات Azure Speech Services — عدّليها بمفاتيحك من Azure Portal
// =====================================================================
const String _kAzureSpeechKey = '9lz61KqwP59MlMj2RS7yTugTWEkRDXBrZ49UDKnxCPAA05XOTpNQJQQJ99CHACI8hq2XJ3w3AAAYACOGYzD0';
const String _kAzureRegion = 'switzerlandnorth'; // مثلاً: uaenorth, westeurope ...
const String _kSttLanguageCode = 'ar-SA'; // أو ar-EG, ar-AE حسب اللهجة
const String _kTtsLanguageCode = 'ar-KW';
const String _kTtsVoiceName = 'ar-KW-FahedNeural';

// ------------------- إعدادات كشف الكلام (لعرض الويف فقط) -------------------
const double _kSilenceDbThreshold = -35.0; // فوق هذا القدر = "فيه كلام"، وتحته "سكوت"

// ------------------- إعدادات سرعة النطق (TTS) -------------------
// راوح بين هالحدين عشان تتحكمين بسرعة الصوت. قللناهم شوي عشان النطق يصير أبطأ.
const double _kTtsMinRate = 0.93;
const double _kTtsMaxRate = 1.02;

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
    await _recorder!.setSubscriptionDuration(const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _speakingTimer?.cancel();
    _recorderSubscription?.cancel();
    _pcmSubscription?.cancel();
    _pcmStreamController?.close();
    _sttSub?.cancel();
    _sttChannel?.sink.close();
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
  // Real-time Speech-to-Text عبر بروتوكول Azure الـ WebSocket (بث حي)
  // =====================================================================
  //
  // بدل الإرسال دفعة-دفعة (REST) بعد كل سكوت، نفتح اتصال WebSocket مع Azure
  // ونبث الصوت أول بأول أثناء ما تتكلمين، وياخذين ردود جزئية (speech.hypothesis)
  // تتحدث لحظياً، وردود نهائية (speech.phrase) بعد كل جملة — تماماً مثل ترجمة
  // قوقل. ملاحظة: بروتوكول Azure الخام (framing) موثّق جزئياً وغير رسمي لـ
  // Flutter، فالكود جرّبته بأفضل معرفتي لكنه ما اختُبر فعلياً على سيرفر Azure
  // حي (ما عندي وصول شبكة لـ Azure هنا) — لازم تجربينه وتتابعين الـ debug
  // console لو صار خطأ بتنسيق الرسائل.

  IOWebSocketChannel? _sttChannel;
  StreamSubscription? _sttSub;
  StreamController<Uint8List>? _pcmStreamController;
  StreamSubscription<Uint8List>? _pcmSubscription;

  String _sttRequestId = '';
  String _confirmedTranscript = '';
  String _currentHypothesis = '';
  bool _isFirstAudioFrame = true;

  bool _isUserSpeaking = false;

  Future<void> _startListening() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('Microphone permission denied');
      _showEmptyTextWarning('صلاحية الوصول للمايكروفون مطلوبة');
      return;
    }

    _confirmedTranscript = '';
    _currentHypothesis = '';
    _isFirstAudioFrame = true;
    _sttRequestId = _newId();

    try {
      await _connectSttSocket();
      await _startStreamingAudio();
    } catch (e) {
      debugPrint('STT START ERROR: $e');
      _showEmptyTextWarning('تعذر بدء الاستماع');
      await _stopListening();
    }
  }

  Future<void> _connectSttSocket() async {
    final connectionId = _newId();
    final uri = Uri.parse(
      'wss://$_kAzureRegion.stt.speech.microsoft.com/speech/recognition/'
      'conversation/cognitiveservices/v1?language=$_kSttLanguageCode&format=simple',
    );

    _sttChannel = IOWebSocketChannel.connect(
      uri,
      headers: {
        'Ocp-Apim-Subscription-Key': _kAzureSpeechKey,
        'X-ConnectionId': connectionId,
      },
    );

    _sttSub = _sttChannel!.stream.listen(
      _handleSttMessage,
      onError: (e) => debugPrint('STT SOCKET ERROR: $e'),
      onDone: () => debugPrint('STT SOCKET CLOSED'),
    );

    // نضمن إن القناة جاهزة قبل ما نرسل speech.config
    await Future.delayed(const Duration(milliseconds: 100));

    final timestamp = DateTime.now().toUtc().toIso8601String();
    final config = jsonEncode({
      'context': {
        'system': {'version': '1.0.0'},
        'os': {'platform': 'Flutter', 'name': 'Flutter', 'version': '1.0.0'},
        'device': {
          'manufacturer': 'unknown',
          'model': 'unknown',
          'version': '1.0.0',
        },
      },
    });

    _sttChannel!.sink.add(
      'Path: speech.config\r\n'
      'X-RequestId: $_sttRequestId\r\n'
      'X-Timestamp: $timestamp\r\n'
      'Content-Type: application/json; charset=utf-8\r\n\r\n'
      '$config',
    );
  }

  Future<void> _startStreamingAudio() async {
    _pcmStreamController = StreamController<Uint8List>();
    _pcmSubscription = _pcmStreamController!.stream.listen(_onPcmChunk);

    await _recorder!.startRecorder(
      toStream: _pcmStreamController!.sink,
      codec: Codec.pcm16,
      sampleRate: 16000,
      numChannels: 1,
    );

    _recorderSubscription = _recorder!.onProgress?.listen((event) {
      if (!mounted) return;
      final db = event.decibels ?? -160.0;

      // تحديث الأمواج المرئية
      double normalized = ((db + 40) / 40).clamp(0.0, 1.0);
      double smooth = _amplitude + (normalized - _amplitude) * 0.3;
      setState(() => _amplitude = smooth);

      // أول ما نكتشف كلام فعلي، الويف يفضل ظاهر لين تطفين المايك بنفسك
      if (db > _kSilenceDbThreshold && !_isUserSpeaking) {
        setState(() => _isUserSpeaking = true);
      }
    });
  }

  void _onPcmChunk(Uint8List chunk) {
    final channel = _sttChannel;
    if (channel == null || chunk.isEmpty) return;

    final timestamp = DateTime.now().toUtc().toIso8601String();
    Uint8List payload = chunk;
    String header;

    if (_isFirstAudioFrame) {
      payload = Uint8List.fromList([..._buildWavHeader(), ...chunk]);
      header = 'Path:audio\r\n'
          'X-RequestId:$_sttRequestId\r\n'
          'X-Timestamp:$timestamp\r\n'
          'Content-Type:audio/x-wav\r\n';
      _isFirstAudioFrame = false;
    } else {
      header = 'Path:audio\r\n'
          'X-RequestId:$_sttRequestId\r\n'
          'X-Timestamp:$timestamp\r\n';
    }

    _sendAudioFrame(channel, header, payload);
  }

  void _sendAudioFrame(
    IOWebSocketChannel channel,
    String header,
    Uint8List payload,
  ) {
    final headerBytes = utf8.encode(header);
    final headerLen = headerBytes.length;
    final frame = BytesBuilder()
      ..addByte((headerLen >> 8) & 0xFF)
      ..addByte(headerLen & 0xFF)
      ..add(headerBytes)
      ..add(payload);
    channel.sink.add(frame.toBytes());
  }

  /// رأس WAV بسيط (44 بايت) بحجم بيانات غير معروف (بث حي)
  List<int> _buildWavHeader() {
    const sampleRate = 16000;
    const bitsPerSample = 16;
    const channels = 1;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;

    final header = BytesBuilder()
      ..add(ascii.encode('RIFF'))
      ..add(_uint32le(0))
      ..add(ascii.encode('WAVE'))
      ..add(ascii.encode('fmt '))
      ..add(_uint32le(16))
      ..add(_uint16le(1))
      ..add(_uint16le(channels))
      ..add(_uint32le(sampleRate))
      ..add(_uint32le(byteRate))
      ..add(_uint16le(blockAlign))
      ..add(_uint16le(bitsPerSample))
      ..add(ascii.encode('data'))
      ..add(_uint32le(0));
    return header.toBytes();
  }

  List<int> _uint32le(int v) =>
      [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
  List<int> _uint16le(int v) => [v & 0xFF, (v >> 8) & 0xFF];

  String _newId() {
    final rnd = math.Random.secure();
    const chars = '0123456789abcdef';
    return List.generate(32, (_) => chars[rnd.nextInt(16)]).join();
  }

  void _handleSttMessage(dynamic message) {
    if (message is! String) return; // ما نتوقع بيانات ثنائية من السيرفر هنا

    final sepIndex = message.indexOf('\r\n\r\n');
    final headerPart = sepIndex == -1 ? message : message.substring(0, sepIndex);
    final bodyPart = sepIndex == -1 ? '' : message.substring(sepIndex + 4);

    String? path;
    for (final line in headerPart.split('\r\n')) {
      if (line.toLowerCase().startsWith('path:')) {
        path = line.substring(5).trim();
      }
    }
    if (path == null || bodyPart.trim().isEmpty) return;

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(bodyPart) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (path) {
      case 'speech.hypothesis':
        final text = (data['Text'] as String?)?.trim() ?? '';
        _currentHypothesis = text;
        if (mounted) {
          setState(() {
            _textContent = _joinTranscript(_confirmedTranscript, _currentHypothesis);
          });
        }
        break;

      case 'speech.phrase':
        final status = data['RecognitionStatus'] as String?;
        final text = ((data['DisplayText'] ?? data['Text']) as String?)?.trim();
        if (status == 'Success' && text != null && text.isNotEmpty) {
          _confirmedTranscript = _joinTranscript(_confirmedTranscript, text);
        }
        _currentHypothesis = '';
        if (mounted) setState(() => _textContent = _confirmedTranscript);
        break;

      default:
        break; // turn.start / speech.startDetected / speech.endDetected / turn.end
    }
  }

  String _joinTranscript(String base, String addition) {
    if (addition.trim().isEmpty) return base.trim();
    if (base.trim().isEmpty) return addition.trim();
    return '${base.trim()} ${addition.trim()}';
  }

  Future<void> _stopListening() async {
    _recorderSubscription?.cancel();
    _recorderSubscription = null;

    if (_recorder != null && _recorder!.isRecording) {
      await _recorder!.stopRecorder();
    }

    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    await _pcmStreamController?.close();
    _pcmStreamController = null;

    // نرسل إشارة "خلصت الصوت" للسيرفر (frame فارغ) بعدها نقفل
    final channel = _sttChannel;
    if (channel != null) {
      try {
        _sendAudioFrame(
          channel,
          'Path:audio\r\n'
          'X-RequestId:$_sttRequestId\r\n'
          'X-Timestamp:${DateTime.now().toUtc().toIso8601String()}\r\n',
          Uint8List(0),
        );
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (_) {}
      await channel.sink.close();
      _sttChannel = null;
    }
    await _sttSub?.cancel();
    _sttSub = null;

    if (mounted) {
      setState(() {
        _amplitude = 0.0;
        _isUserSpeaking = false;
        _currentHypothesis = '';
      });
    }
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

    final preparedText = _prepareTextForNaturalSpeech(_textContent);

    final ssml = '''<speak version='1.0' xml:lang='$_kTtsLanguageCode'>
  <voice xml:lang='$_kTtsLanguageCode' name='$_kTtsVoiceName'>
    ${_buildExpressiveSsml(preparedText)}
  </voice>
</speak>''';

    try {
      final response = await http.post(
        url,
        headers: {
          'Ocp-Apim-Subscription-Key': _kAzureSpeechKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-24khz-160kbitrate-mono-mp3',
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

  String _prepareTextForNaturalSpeech(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;
    const endings = ['.', '؟', '!', '،', '؛'];
    if (endings.any((e) => trimmed.endsWith(e))) return trimmed;
    return '$trimmed.';
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// يضيف سكتات قصيرة بعد علامات الترقيم داخل الجملة الواحدة (بعد الفواصل
  /// مثلاً)، يُستدعى بعد الـ escape.
  String _addNaturalPauses(String escapedText) {
    return escapedText.replaceAll('، ', '،<break time="180ms"/> ');
  }

  /// يقسم النص لجمل، وكل جملة يديها نبرة/سرعة مختلفة شوي بشكل عشوائي
  /// بسيط، عشان نكسر الرتابة الآلية اللي تصير لما كل النص يتنطق بنفس
  /// النبرة الثابتة من أول لآخر. السرعة الأساسية دحين أبطأ شوي
  /// (_kTtsMinRate إلى _kTtsMaxRate) حسب طلبك.
  String _buildExpressiveSsml(String text) {
    final sentences = _splitIntoSentences(text);
    if (sentences.isEmpty) {
      return '<prosody rate="${_kTtsMinRate.toStringAsFixed(2)}" pitch="+0%">${_addNaturalPauses(_escapeXml(text))}</prosody>';
    }

    final rnd = math.Random();
    final rateRange = _kTtsMaxRate - _kTtsMinRate;
    final buffer = StringBuffer();
    for (var i = 0; i < sentences.length; i++) {
      final sentence = sentences[i].trim();
      if (sentence.isEmpty) continue;

      final pitchOffset = -3 + rnd.nextInt(7); // بين -3% و +3%
      final rate = _kTtsMinRate + rnd.nextDouble() * rateRange;
      final pitchStr = pitchOffset >= 0 ? '+$pitchOffset%' : '$pitchOffset%';

      buffer.write(
        '<prosody rate="${rate.toStringAsFixed(2)}" pitch="$pitchStr">'
        '${_addNaturalPauses(_escapeXml(sentence))}'
        '</prosody>',
      );
      if (i != sentences.length - 1) {
        buffer.write('<break time="280ms"/>');
      }
    }
    return buffer.toString();
  }

  List<String> _splitIntoSentences(String text) {
    final pattern = RegExp(r'(?<=[.؟!؛])\s+');
    return text.split(pattern).where((s) => s.trim().isNotEmpty).toList();
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
    final showWaveform = _isRecording && _isUserSpeaking;
    final hasText = _textContent.trim().isNotEmpty;

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
                  if (!hasText) ...[
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (showWaveform) ...[
                              _buildRecordingWaveform(),
                              const SizedBox(height: 16),
                            ],
                            Text(
                              !_isRecording
                                  ? 'اضغط على المايك للبدء'
                                  : (showWaveform
                                      ? 'جارِ الاستماع...'
                                      : 'ابدأ التحدث الآن...'),
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
                    if (showWaveform) ...[
                      _buildRecordingWaveform(),
                      const SizedBox(height: 16),
                      const Divider(color: NabeehColors.slate100),
                      const SizedBox(height: 16),
                    ],
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _textContent,
                          style: const TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: NabeehColors.dark,
                            letterSpacing: -0.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    if (!_isRecording) ...[
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
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
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
                          'أنا بحاجة للمساعدة',
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
