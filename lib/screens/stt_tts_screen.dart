import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/custom_widgets.dart';
// Removed NabeehScreenScaffold import – now using a custom header
import 'nabeeh_colors.dart';

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
    _recorder?.closeRecorder();
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
    // ─── Directionality set to RTL for Arabic layout ────────────────────────
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _buildHeader(context), // Custom header matching EditProfileScreen
            Expanded(
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic', // Consistent Arabic font
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      BentoCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'اختر طريقة التفاعل',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: NabeehColors.dark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildModeSwitcher(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 400,
                        child: AnimatedSwitcher(
                          duration: 250.ms,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 52, bottom: 20, right: 20, left: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB8D4F0), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
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

  // (The rest of the widget methods remain unchanged, only styling is consistent)

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
    return Column(
      children: [
        Expanded(
          child: BentoCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: _buildStatusBadge(
                    isActive: _isRecording,
                    activeText: 'جاري الاستماع...',
                    inactiveText: 'جاهز',
                  ),
                ),
                if (_textContent.isEmpty) ...[
                  Expanded(
                    child: Center(
                      child: Text(
                        _isRecording
                            ? 'ابدأ التحدث الآن...'
                            : 'اضغط على المايك للبدء',
                        style: const TextStyle(
                          color: NabeehColors.slate500,
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  if (_isRecording) ...[
                    _buildRecordingWaveform(),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    _getHeadingFromText(_textContent),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NabeehColors.dark,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: NabeehColors.slate100),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [const SizedBox(height: 6)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 36),
        GestureDetector(
          onTap: _toggleRecording,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _isRecording
                  ? const LinearGradient(
                      colors: [Color(0xFF181059), Color(0xFF1773CF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: _isRecording
                  ? null
                  : NabeehColors.slate200.withValues(alpha: 0.5),
              border: _isRecording
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.5,
                    )
                  : null,
              boxShadow: _isRecording
                  ? [
                      BoxShadow(
                        color: const Color(0xFF181059).withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Icon(
                _isRecording ? LucideIcons.mic : LucideIcons.micOff,
                size: 38,
                color: _isRecording ? Colors.white : NabeehColors.slate400,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildTtsView() {
    return Column(
      children: [
        Expanded(
          child: BentoCard(
            padding: const EdgeInsets.all(16),

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
                        color: NabeehColors.slate300,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    cursorColor: NabeehColors.blue,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: NabeehColors.dark,
                      height: 1.6,
                    ),
                  ),
                ),
                if (_textContent.isEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          [
                                'مرحباً بك',
                                'كيف حالك؟',
                                'أنا بحاجة لمساعدة',
                                'شكراً لك',
                              ]
                              .map(
                                (phrase) => Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    start: 8,
                                  ),
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
                      '${_textContent.length} حرف',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
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
        const SizedBox(height: 36),
        _buildVisualizer(
          icon: LucideIcons.volume2,
          isActive: _isSpeaking,
          activeColor: NabeehColors.blue,
          small: true,
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF181059), Color(0xFF1773CF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: TextButton(
            onPressed: _speakText,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _isSpeaking ? 'جاري النطق...' : 'نطق النص',
              style: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
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
                  color: isActive
                      ? NabeehColors.lightBlue
                      : NabeehColors.slate300,
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
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: NabeehColors.slate400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingWaveform() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: NabeehColors.slate50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NabeehColors.slate100),
      ),
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
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 6,
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

  Widget _buildVisualizer({
    required IconData icon,
    required bool isActive,
    Color activeColor = NabeehColors.blue,
    bool small = false,
  }) {
    double size = small ? 90 : 160;
    return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.12)
                : NabeehColors.slate50,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? activeColor.withValues(alpha: 0.18)
                  : NabeehColors.slate100,
              width: 1.5,
            ),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.18),
                  blurRadius: 26,
                  spreadRadius: 6,
                ),
            ],
          ),
          child: Center(
            child: Icon(
              icon,
              color: isActive ? activeColor : NabeehColors.slate400,
              size: size * 0.4,
            ),
          ),
        )
        .animate(
          onPlay: (controller) =>
              isActive ? controller.repeat(reverse: true) : null,
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
      child: AnimatedContainer(
        duration: 200.ms,
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDanger
              ? Colors.red.withValues(alpha: 0.05)
              : NabeehColors.slate50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDanger
                ? Colors.red.withValues(alpha: 0.12)
                : NabeehColors.slate100,
          ),
          boxShadow: [
            BoxShadow(
              color: NabeehColors.dark.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
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
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDanger ? Colors.red.shade400 : NabeehColors.slate400,
                letterSpacing: 0.2,
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
