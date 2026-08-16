import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';
import 'nabeeh_colors.dart';
import '../services/sign_language_mode.dart';
import '../services/watch_audio_socket.dart';
import '../services/audio_utils.dart';
import '../services/event_classifier_service.dart';
import '../widgets/watch_ip_dialog.dart';
import '../features/categories/data/models/sound_setting_model.dart';
import '../features/categories/data/services/category_service.dart';
import 'sign_language_player_screen.dart';

const _kChunkSeconds = 3;
const _kBytesPerChunk =
    WatchAudioSocket.sampleRate * 2 * _kChunkSeconds; // 16-bit mono PCM

const Map<String, String> _kCategoryLabels = {
  'doorbell': 'جرس الباب',
  'knock': 'طرق على الباب',
  'baby_cry': 'بكاء طفل',
  'fire_alarm': 'إنذار حريق',
  'adhan': 'أذان',
  'quran_recitation': 'تلاوة قرآن',
  'na': 'لا يوجد صوت مهم',
};

// فقط هذي الفئات تظهر كإشعارات داخل بطاقة "الصوت المكتشف حالياً"
const Map<String, String> _kAlertEmojis = {
  'fire_alarm': '🚨',
  'adhan': '🕌',
  'baby_cry': '👶🏻',
  'doorbell': '🔔',
  'knock': '✊🏻',
};

// رموز عرض النتيجة على شاشة الساعة نفسها — بروتوكول '#' + حرف الفئة
const Map<String, String> _kWatchDetectionCodes = {
  'doorbell': 'D',
  'knock': 'K',
  'baby_cry': 'B',
  'fire_alarm': 'F',
  'adhan': 'A',
};

const _kMaxDetectionEntries = 30;

// تحويل تسمية فئة الـ API إلى soundId المستخدم بميزة "المجموعات الصوتية"
const Map<String, String> _kApiLabelToSoundId = {
  'doorbell': 'door_bell',
  'knock': 'door_knock',
  'baby_cry': 'baby_cry',
  'fire_alarm': 'fire_alarm',
  'adhan': 'adhan',
};

// مقياس التطبيق: 1=خفيف، 2=متوسط، 3=قوي — مقياس الساعة: 1=قوي، 2=متوسط، 3=خفيف
// (معكوسين) — نفس التحويل ينطبق على النمط والشدة لأنهم بنفس المقياس
int _toWatchVibrationCode(int appValue) => 4 - appValue;

class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  final _watchSocket = WatchAudioSocket();
  final List<int> _pcmBuffer = [];
  bool _isClassifying = false;

  String? _watchIp;
  bool isListening = false;
  bool _isConnecting = false;
  double _audioLevel = 0.0;
  String detectedSound = 'اضغط على المايك لبدء الاستماع من الساعة';
  final List<({String emoji, String label, String time})> _detections = [];

  // إعدادات المجموعة الصوتية المفعّلة (تفعيل + نمط/شدة الاهتزاز لكل صوت)
  final CategoryService _categoryService = CategoryService.withDefaults();
  Map<String, SoundSettingModel> _activeSoundSettings =
      _defaultSoundSettingsMap();

  static Map<String, SoundSettingModel> _defaultSoundSettingsMap() => {
    for (final sound in CategoryService.defaultSounds) sound.soundId: sound,
  };

  Future<void> _loadActiveSoundSettings() async {
    try {
      final categories = await _categoryService.getCategories();
      final activeMatches = categories.where((c) => c.isEnabled);
      if (activeMatches.isEmpty) {
        _activeSoundSettings = _defaultSoundSettingsMap();
        return;
      }
      final active = activeMatches.first;
      _activeSoundSettings = {
        for (final sound in active.sounds) sound.soundId: sound,
      };
    } catch (_) {
      // نرجع للإعدادات الافتراضية لو تعذر التحميل — عشان الأصوات الحرجة
      // زي إنذار الحريق تضل تُنبّه حتى لو فشل جلب إعدادات المستخدم
      _activeSoundSettings = _defaultSoundSettingsMap();
    }
  }

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadWatchIp();
  }

  Future<void> _loadWatchIp() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _watchIp = prefs.getString(kWatchIpPrefsKey));
  }

  void _handleTap(String videoAsset, VoidCallback action) {
    if (signLanguageModeNotifier.value) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => SignLanguagePlayerScreen(
          videoAsset: videoAsset,
          onFinished: action,
        ),
      );
    } else {
      action();
    }
  }

  Future<String?> _promptForWatchIp() async {
    final ip = await promptForWatchIp(context);
    if (ip != null && mounted) setState(() => _watchIp = ip);
    return ip;
  }

  @override
  void dispose() {
    _waveController.dispose();
    _watchSocket.stop();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (isListening) {
      await _stopListening();
      return;
    }

    var ip = _watchIp;
    if (ip == null || ip.isEmpty) {
      ip = await _promptForWatchIp();
      if (ip == null) return;
    }

    setState(() {
      _isConnecting = true;
      detectedSound = 'جاري الاتصال بالساعة...';
    });

    try {
      _pcmBuffer.clear();
      _detections.clear();
      await _loadActiveSoundSettings();
      await _watchSocket.connect(
        host: ip,
        onData: _onAudioData,
        onError: _onSocketError,
        onDone: _onSocketDone,
      );
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        isListening = true;
        detectedSound = 'جاري الاستماع من الساعة...';
        _waveController.repeat();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        isListening = false;
        detectedSound = 'تعذّر الاتصال بالساعة — تأكد من عنوان IP والشبكة';
      });
    }
  }

  void _onAudioData(Uint8List data) {
    setState(() => _audioLevel = pcm16PeakAmplitude(data));

    _pcmBuffer.addAll(data);
    if (_pcmBuffer.length >= _kBytesPerChunk) {
      final chunk = Uint8List.fromList(_pcmBuffer.sublist(0, _kBytesPerChunk));
      _pcmBuffer.removeRange(0, _kBytesPerChunk);
      // نتجاهل هذا المقطع لو فيه طلب سابق ما خلص بعد — عشان ما تتكدس
      // الطلبات ويصير "انفجار" نتائج متأخرة لما السيرفر يرد أخيراً.
      if (!_isClassifying) {
        _classifyChunk(chunk);
      }
    }
  }

  Future<void> _classifyChunk(Uint8List pcmChunk) async {
    _isClassifying = true;
    final wavBytes = pcm16ToWav(
      pcmChunk,
      sampleRate: WatchAudioSocket.sampleRate,
    );
    try {
      final result = await EventClassifierService.classifyWavChunk(wavBytes);
      debugPrint(
        'classifyWavChunk result: label=${result.label} shouldAlert=${result.shouldAlert} debugReason=${result.debugReason}',
      );
      if (!mounted || !isListening) return;
      final emoji = _kAlertEmojis[result.label];
      final soundId = _kApiLabelToSoundId[result.label];
      final soundSetting = soundId != null
          ? _activeSoundSettings[soundId]
          : null;
      final isSoundEnabled = soundSetting?.isEnabled ?? false;

      if (result.shouldAlert && emoji != null && isSoundEnabled) {
        setState(() {
          _detections.insert(
            0,
            (
              emoji: emoji,
              label: _kCategoryLabels[result.label] ?? result.label,
              time: _formatDetectionTime(DateTime.now()),
            ),
          );
          if (_detections.length > _kMaxDetectionEntries) {
            _detections.removeLast();
          }
        });

        final watchCode = _kWatchDetectionCodes[result.label];
        if (watchCode != null) {
          _watchSocket.sendDetectionCode(
            watchCode,
            pattern: _toWatchVibrationCode(soundSetting!.vibrationPattern),
            power: _toWatchVibrationCode(soundSetting.vibrationPower),
          );
        }
      }
      if (result.shouldAlert && result.fireAlarmSafetyFlag) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 احتمال إنذار حريق — تحقق فورًا'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('classifyWavChunk failed: $e');
    } finally {
      _isClassifying = false;
    }
  }

  String _formatDetectionTime(DateTime time) {
    final isAm = time.hour < 12;
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour12:$minute ${isAm ? 'ص' : 'م'}';
  }

  void _onSocketError(Object error) {
    debugPrint('Watch socket error: $error');
    _stopListening();
  }

  void _onSocketDone() {
    if (isListening) _stopListening();
  }

  Future<void> _stopListening() async {
    await _watchSocket.stop();
    _pcmBuffer.clear();
    if (!mounted) return;
    setState(() {
      isListening = false;
      _isConnecting = false;
      _audioLevel = 0.0;
      _waveController.stop();
      detectedSound = 'الميكروفون متوقف';
      _detections.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
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
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildWatchIpRow(),
                        const SizedBox(height: 40),
                        _buildMicAndWaves(),
                        const SizedBox(height: 60),
                        _buildCurrentSoundCard(),
                        const SizedBox(height: 40),
                      ],
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 64, bottom: 20, right: 20, left: 20),
      child: Row(
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
          const Expanded(
            child: Text(
              'الاستشعار الصوتي',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF181059),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: signLanguageModeNotifier,
            builder: (context, isActive, _) => GestureDetector(
              onTap: () {
                signLanguageModeNotifier.value = !isActive;
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF0B4D2C),
                            Color(0xFF0B4D2C),
                            NabeehColors.green,
                          ],
                          stops: [0.09, 0.30, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFF181059),
                            Color(0xFF181059),
                            Color(0xFF1773CF),
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
                    color: Colors.white,
                    colorBlendMode: BlendMode.srcIn,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchIpRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: isListening ? null : _promptForWatchIp,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.watch, size: 14, color: NabeehColors.slate500),
            const SizedBox(width: 6),
            Text(
              _watchIp == null || _watchIp!.isEmpty
                  ? 'اضغط لتحديد عنوان IP للساعة'
                  : 'الساعة: $_watchIp',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 12,
                color: NabeehColors.slate500,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!isListening) ...[
              const SizedBox(width: 6),
              Icon(
                LucideIcons.pencil,
                size: 12,
                color: NabeehColors.slate500,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMicAndWaves() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _isConnecting
              ? null
              : () => _handleTap(
                  'assets/videos/sign_start_listening.mp4',
                  () => _toggleListening(),
                ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening
                  ? NabeehColors.lightBlue.withValues(alpha: 0.1)
                  : NabeehColors.slate200.withValues(alpha: 0.5),
              boxShadow: isListening
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
              child: _isConnecting
                  ? const CircularProgressIndicator(
                      color: NabeehColors.lightBlue,
                    )
                  : Icon(
                      isListening ? LucideIcons.mic : LucideIcons.micOff,
                      size: 50,
                      color: isListening
                          ? NabeehColors.lightBlue
                          : NabeehColors.slate400,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 40),

        SizedBox(
          height: 60,
          child: AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(15, (index) {
                  final offset = index * 0.4;

                  final baseRipple = (math.sin(
                              (_waveController.value * 2 * math.pi) +
                                  offset) +
                          1) /
                      2;

                  final heightVal = isListening
                      ? baseRipple * (_audioLevel + 0.1)
                      : 0.0;

                  final barHeight = 10 + (heightVal * 50);

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 6,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: isListening
                          ? NabeehColors.lightBlue.withValues(alpha: 0.8)
                          : NabeehColors.slate300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          isListening
              ? 'جاري تحليل الأصوات من حولك...'
              : 'الاستماع متوقف حالياً',
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isListening ? NabeehColors.slate500 : NabeehColors.slate400,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSoundCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color.fromARGB(255, 235, 233, 229)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isListening ? LucideIcons.activity : LucideIcons.moon,
                  color: isListening
                      ? const Color(0xFF181059)
                      : NabeehColors.slate400,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'الصوت المكتشف حالياً',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: NabeehColors.slate500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    detectedSound,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: isListening ? 22 : 18,
                      fontWeight: FontWeight.bold,
                      color: isListening
                          ? NabeehColors.darkBlue
                          : NabeehColors.slate400,
                    ),
                  ),
                ),
                if (isListening)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            if (isListening && _detections.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: ListView(
                  children: _detections.map(_buildDetectionEntry).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionEntry(
    ({String emoji, String label, String time}) detection,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF181059), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(detection.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(
                detection.label,
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181059),
                ),
              ),
            ],
          ),
          Text(
            detection.time,
            style: const TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 11,
              color: NabeehColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}
