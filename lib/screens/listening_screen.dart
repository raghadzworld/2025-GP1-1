import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:math' as math;
import 'dart:async';
import 'nabeeh_colors.dart';
import '../services/sign_language_mode.dart';
import '../services/watch_audio_socket.dart';
import '../widgets/watch_ip_dialog.dart';
import 'sign_language_player_screen.dart';

class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  StreamSubscription<Map<String, dynamic>?>? _updateSub;

  String? _watchIp;
  bool isListening = false;
  bool _isConnecting = false;
  bool _serviceAcknowledged = false;
  double _audioLevel = 0.0;
  String detectedSound = 'اضغط على المايك لبدء الاستماع من الساعة';
  List<Map<String, dynamic>> _detections = [];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadWatchIp();
    _updateSub = FlutterBackgroundService().on('update').listen(_onServiceUpdate);
    _syncWithRunningService();
  }

  // الخدمة الخلفية ممكن تكون شغّالة أصلاً (المستخدم بدأ الاستماع، طلع من
  // الصفحة أو قفل التطبيق، ورجع فتحها من جديد) — نطلب آخر حالة عشان
  // الواجهة تعكس الوضع الصحيح بدل ما تبدأ فاضية.
  Future<void> _syncWithRunningService() async {
    final running = await FlutterBackgroundService().isRunning();
    if (running) {
      FlutterBackgroundService().invoke('request_status');
    }
  }

  void _onServiceUpdate(Map<String, dynamic>? event) {
    if (event == null || !mounted) return;
    _serviceAcknowledged = true;
    setState(() {
      isListening = event['isListening'] as bool? ?? false;
      _isConnecting = event['isConnecting'] as bool? ?? false;
      detectedSound = event['statusText'] as String? ?? detectedSound;
      _audioLevel = (event['audioLevel'] as num?)?.toDouble() ?? 0.0;
      final rawDetections = event['detections'] as List?;
      if (rawDetections != null) {
        _detections = rawDetections
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    });
    if (isListening) {
      _waveController.repeat();
    } else {
      _waveController.stop();
    }
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
    _updateSub?.cancel();
    // نتعمّد عدم إيقاف الخدمة هنا — المفروض تضل شغّالة حتى بعد ما نطلع
    // من هذي الصفحة، لين المستخدم يوقفها بنفسه من زر المايك.
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (isListening) {
      FlutterBackgroundService().invoke('stop_listening');
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

    await FlutterBackgroundService().startService();

    // بدء تشغيل الـ isolate الخلفي ما يعني إنه جاهز يستقبل أوامرنا فورًا —
    // لو وصل أمرنا قبل ما يسجّل مستمعه، البلجن يتجاهله بصمت بدون أي رد.
    // نعيد الإرسال كل شوي لين يوصلنا أول رد يؤكد إن الخدمة استلمت.
    _serviceAcknowledged = false;
    for (var attempt = 0; attempt < 8 && !_serviceAcknowledged && mounted; attempt++) {
      FlutterBackgroundService().invoke('start_listening', {'watchIp': ip});
      await Future.delayed(const Duration(milliseconds: 500));
    }
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

  Widget _buildDetectionEntry(Map<String, dynamic> detection) {
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
              Text(
                detection['emoji'] as String? ?? '',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 10),
              Text(
                detection['label'] as String? ?? '',
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
            detection['time'] as String? ?? '',
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
