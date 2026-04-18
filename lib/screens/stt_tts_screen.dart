import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'Nabeeh_Colors.dart';

class SttTtsScreen extends StatefulWidget {
  const SttTtsScreen({super.key});

  @override
  State<SttTtsScreen> createState() => _SttTtsScreenState();
}

class _SttTtsScreenState extends State<SttTtsScreen> {
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

  @override
  void initState() {
    super.initState();
    _ttsController = TextEditingController();
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
    _recorder?.closeRecorder();
    _textFocusNode.dispose();
    _ttsController.dispose();
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
      await _startListening();
    }
    setState(() {
      _isRecording = !_isRecording;
      if (_isRecording) {
        _textContent = 'مرحباً، كيف يمكنني مساعدتك اليوم؟';
      }
    });
  }

  Future<void> _startListening() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('Microphone permission denied');
      return;
    }

    try {
      await _recorder!.startRecorder(
        toFile: 'temp_record.aac',
        codec: Codec.aacADTS,
      );

      _recorderSubscription = _recorder!.onProgress?.listen((event) {
        if (!mounted) return;
        final db = event.decibels ?? -40.0;
        double normalized = ((db + 40) / 40).clamp(0.0, 1.0);
        double smooth = _amplitude + (normalized - _amplitude) * 0.3;
        setState(() {
          _amplitude = smooth;
        });
      });
    } catch (e) {
      debugPrint('RECORDER ERROR: $e');
    }
  }

  Future<void> _stopListening() async {
    _recorderSubscription?.cancel();
    _recorderSubscription = null;
    await _recorder?.stopRecorder();
    setState(() {
      _amplitude = 0.0;
    });
  }

  void _clearText() {
    setState(() {
      _textContent = '';
      _isRecording = false;
      _ttsController.clear();
      _stopListening();
    });
  }

  void _copyText() {
    if (_textContent.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _textContent));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ النص'),
          duration: Duration(seconds: 1),
          backgroundColor: NabeehColors.dark,
        ),
      );
    }
  }

  void _speakText() {
    if (_textContent.isEmpty) return;

    setState(() => _isSpeaking = true);
    _speakingTimer?.cancel();
    _speakingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isSpeaking = false);
    });
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
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 64),
          _buildHeader(context),
          const SizedBox(height: 32),
          _buildModeSwitcher(),
          const SizedBox(height: 24),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _isSttMode ? _buildSttView() : _buildTtsView(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المساعد الذكي',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.slate400,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'التواصل',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.dark,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NabeehColors.slate100),
              ),
              child: const Icon(LucideIcons.arrowLeft, color: NabeehColors.slate400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: NabeehColors.slate100.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildModeTab(
                title: 'استماع',
                isSelected: _isSttMode,
                onTap: () => _switchMode(true),
              ),
            ),
            Expanded(
              child: _buildModeTab(
                title: 'تحدث',
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
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? NabeehColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: NabeehColors.accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isSelected ? NabeehColors.dark : NabeehColors.slate400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSttView() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: _mainCardDecoration(),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  child: _buildStatusBadge(
                    isActive: _isRecording,
                    activeText: 'جاري الاستماع...',
                    inactiveText: 'جاهز',
                  ),
                ),
                _textContent.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _isRecording
                                ? _buildMicWithRipples()
                                : _buildVisualizer(
                                    icon: LucideIcons.mic,
                                    isActive: false,
                                  ),
                            const SizedBox(height: 32),
                            Text(
                              _isRecording ? 'ابدأ التحدث الآن...' : 'اضغط على المايك للبدء',
                              style: const TextStyle(
                                color: NabeehColors.slate200,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 40),
                          Text(
                            _getHeadingFromText(_textContent),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: NabeehColors.dark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: NabeehColors.slate100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'نص',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: NabeehColors.slate400,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '·',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: NabeehColors.slate300,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _textContent.split(' ').take(3).join(' '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: NabeehColors.slate400,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Divider(color: NabeehColors.slate100),
                          const SizedBox(height: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'النص الكامل',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: NabeehColors.slate400,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _textContent,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: NabeehColors.dark,
                                      height: 1.6,
                                    ),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!_isRecording)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildSmallAction(
                                  icon: LucideIcons.copy,
                                  label: 'نسخ',
                                  onTap: _copyText,
                                ),
                                const SizedBox(width: 8),
                                _buildSmallAction(
                                  icon: LucideIcons.x,
                                  label: 'مسح',
                                  isDanger: true,
                                  onTap: _clearText,
                                ),
                              ],
                            ),
                        ],
                      ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildActionButton(
          icon: LucideIcons.mic,
          color: _isRecording ? Colors.red : NabeehColors.dark,
          onTap: _toggleRecording,
        ),
      ],
    );
  }

  Widget _buildTtsView() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: _mainCardDecoration(),
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
                      hintStyle: TextStyle(color: NabeehColors.slate200),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: NabeehColors.dark,
                      height: 1.5,
                    ),
                  ),
                ),
                if (_textContent.isEmpty)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      'مرحباً بك',
                      'كيف حالك؟',
                      'أنا بحاجة لمساعدة',
                      'شكراً لك'
                    ].map((phrase) => _buildPhrase(phrase)).toList(),
                  ),
                const SizedBox(height: 24),
                const Divider(color: NabeehColors.slate50),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildToolsIcon(LucideIcons.x, onTap: _clearText),
                        const SizedBox(width: 8),
                        _buildToolsIcon(LucideIcons.star, onTap: () {}),
                      ],
                    ),
                    Text(
                      '${_textContent.length} حرف',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: NabeehColors.slate200,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        _buildVisualizer(
          icon: LucideIcons.volume2,
          isActive: _isSpeaking,
          activeColor: NabeehColors.blue,
          small: true,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _speakText,
          style: ElevatedButton.styleFrom(
            backgroundColor: NabeehColors.dark,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(_isSpeaking ? 'جاري النطق...' : 'نطق النص'),
        ),
      ],
    );
  }

  BoxDecoration _mainCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(40),
      border: Border.all(color: NabeehColors.slate100),
      boxShadow: [
        BoxShadow(
          color: NabeehColors.dark.withValues(alpha: 0.05),
          blurRadius: 30,
        ),
      ],
    );
  }

  Widget _buildStatusBadge({
    required bool isActive,
    required String activeText,
    required String inactiveText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: NabeehColors.slate50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NabeehColors.slate100),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? Colors.red : NabeehColors.slate300,
              shape: BoxShape.circle,
            ),
          )
              .animate(
                onPlay: (controller) => isActive ? controller.repeat() : null,
              )
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.2, 1.2),
                duration: 800.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(width: 8),
          Text(
            isActive ? activeText : inactiveText,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: NabeehColors.slate400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicWithRipples() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.red.withValues(
                  alpha: 0.08 + 0.25 * _amplitude,
                ),
                width: 2,
              ),
            ),
          )
              .animate(
                onPlay: (controller) => _isRecording ? controller.repeat() : null,
              )
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.25, 1.25),
                duration: 1200.ms,
                curve: Curves.easeInOut,
              )
              .fadeIn(duration: 400.ms),
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.red.withValues(
                  alpha: 0.05 + 0.2 * _amplitude,
                ),
                width: 2,
              ),
            ),
          )
              .animate(
                delay: 300.ms,
                onPlay: (controller) => _isRecording ? controller.repeat() : null,
              )
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.3, 1.3),
                duration: 1400.ms,
                curve: Curves.easeInOut,
              )
              .fadeIn(duration: 400.ms),
          _buildVisualizer(
            icon: LucideIcons.mic,
            isActive: true,
            activeColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizer({
    required IconData icon,
    required bool isActive,
    Color activeColor = NabeehColors.blue,
    bool small = false,
  }) {
    double size = small ? 100 : 160;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isActive ? activeColor : NabeehColors.slate50,
        shape: BoxShape.circle,
        border: isActive ? null : Border.all(color: NabeehColors.slate100),
      ),
      child: Center(
        child: Icon(
          icon,
          color: isActive ? Colors.white : NabeehColors.slate200,
          size: size * 0.4,
        ),
      ),
    )
        .animate(
          onPlay: (controller) => isActive ? controller.repeat(reverse: true) : null,
        )
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.05, 1.05),
          duration: 800.ms,
          curve: Curves.easeInOut,
        );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 40),
      ),
    );
  }

  Widget _buildSmallAction({
    required IconData icon,
    required String label,
    bool isDanger = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDanger ? Colors.red.withValues(alpha: 0.05) : NabeehColors.slate50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 12,
              color: isDanger ? Colors.red.shade400 : NabeehColors.slate400,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isDanger ? Colors.red.shade400 : NabeehColors.slate400,
              ),
            ),
          ],
        ),
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
        ),
        child: Text(
          phrase,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
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
        ),
        child: Icon(icon, size: 20, color: NabeehColors.slate400),
      ),
    );
  }
}