import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/watch_audio_socket.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/watch_ip_dialog.dart';
import 'nabeeh_colors.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  String? _watchIp;
  bool _isConnected = false;
  int? _batteryPercent; // null = لم يُستعلَم بعد، -1 = غير متوفرة
  int? _lastSyncSecondsAgo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadIpAndQuery();
  }

  Future<void> _loadIpAndQuery() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _watchIp = prefs.getString(kWatchIpPrefsKey));
    await _queryStatus();
  }

  Future<void> _queryStatus() async {
    final ip = _watchIp;
    if (ip == null || ip.isEmpty) return;

    setState(() => _isLoading = true);
    final status = await WatchAudioSocket.queryStatus(ip);
    debugPrint(
      status == null
          ? 'WatchAudioSocket.queryStatus($ip) failed — no response'
          : 'WatchAudioSocket.queryStatus($ip) => isConnected=${status.isConnected} battery=${status.batteryPercent} lastSync=${status.lastSyncSecondsAgo}',
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (status != null) {
        _isConnected = status.isConnected;
        _batteryPercent = status.batteryPercent;
        _lastSyncSecondsAgo = status.lastSyncSecondsAgo;
      } else {
        _isConnected = false;
        _batteryPercent = null;
        _lastSyncSecondsAgo = null;
      }
    });
  }

  Future<void> _editWatchIp() async {
    final ip = await promptForWatchIp(context);
    if (ip != null && mounted) {
      setState(() => _watchIp = ip);
      await _queryStatus();
    }
  }

  // القيمة الخام بالثواني تمثّل مدة الاتصال الحالي وهي متصلة (تزيد من صفر)،
  // أو مدة الانقطاع لو انقطعت — التنسيق يصير هنا بالتطبيق بدل الفيرموير
  // عشان نقدر نغيّره وقت ما نبي بدون تعديل الساعة.
  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds ثانية';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '$minutes دقيقة';
    final hours = minutes ~/ 60;
    return '$hours ساعة';
  }

  String _formatSyncStatus(int seconds) {
    final duration = _formatDuration(seconds);
    return _isConnected ? 'متصلة منذ $duration' : 'انقطعت قبل $duration';
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
          child: Column(
          children: [
            _buildHeader(context),
            _buildWatchIpRow(),
            Expanded(
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                child: RefreshIndicator(
                  onRefresh: _queryStatus,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          _buildWatchHeroCard(),
                          const SizedBox(height: 16),
                          _buildMetricsGrid(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  // ─── Custom Header ──────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 64, bottom: 20, right: 20, left: 20),
      child: Row(
        children: [
          // العنوان
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                ' الساعة',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF181059),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // أيقونة لغة الإشارة
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
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
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1773CF).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
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
        ],
      ),
    );
  }

  Widget _buildWatchIpRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: _editWatchIp,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.watch, size: 14, color: NabeehColors.gray),
            const SizedBox(width: 6),
            Text(
              _watchIp == null || _watchIp!.isEmpty
                  ? 'اضغط لتحديد عنوان IP للساعة'
                  : 'الساعة: $_watchIp',
              style: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 12,
                color: NabeehColors.gray,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(LucideIcons.pencil, size: 12, color: NabeehColors.gray),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchHeroCard() {
    return BentoCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 16,
      border: Border.all(color: const Color(0xFFB8D4F0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      'حـالة الساعـة:',
                      style: const TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF181059),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1773CF),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Central watch icon ring (now also matching the style)
          SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isConnected)
                  Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1773CF), Color(0xFF1773CF)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB8D4F0),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      )
                      .animate(
                        onPlay: (controller) => controller.repeat(reverse: true),
                      )
                      .scale(
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1.05, 1.05),
                        duration: 2500.ms,
                      )
                else
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF94A3B8).withValues(alpha: 0.18),
                    ),
                  ),
                Container(
                  width: 194,
                  height: 194,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: NabeehColors.slate50,
                  ),
                ),
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NabeehColors.slate50.withValues(alpha: 0.7),
                  ),
                  child: Icon(
                    Icons.watch_rounded,
                    size: 80,
                    color: _isConnected
                        ? const Color(0xFF1773CF)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: (_isConnected ? const Color(0xFF22C55E) : Colors.grey)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (_isConnected ? const Color(0xFF22C55E) : Colors.grey)
                      .withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isConnected
                          ? const Color(0xFF22C55E)
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isConnected ? 'متصلة' : 'غير متصلة',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _isConnected
                          ? const Color(0xFF22C55E)
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Row(
      children: [
        Expanded(child: _buildSyncCard()),
        const SizedBox(width: 16),
        Expanded(child: _buildBatteryCard()),
      ],
    );
  }

  // نمط موحّد لحالة "غير متاح" داخل البطاقتين، بأيقونة ملوّنة داخل دائرة خفيفة
  Widget _buildUnavailableState(IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          'غير متاح',
          style: const TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncCard() {
    final accent = _isConnected ? const Color(0xFF22C55E) : const Color(0xFF1773CF);
    return SizedBox(
      height: 220,
      child: BentoCard(
        borderRadius: 16,
        border: Border.all(color: const Color(0xFFB8D4F0)),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // العنوان في الأعلى
            const Text(
              'آخر تزامن',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF181059),
              ),
            ),
            // مسافة حقيقية بين العنوان والمحتوى
            Expanded(
              child: Center(
                child: _lastSyncSecondsAgo != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              _isConnected
                                  ? LucideIcons.wifi
                                  : LucideIcons.wifiOff,
                              color: accent,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _formatSyncStatus(_lastSyncSecondsAgo!),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF181059),
                            ),
                          ),
                        ],
                      )
                    : _buildUnavailableState(LucideIcons.wifiOff, accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryCard() {
    const accent = Color(0xFFF59E0B);
    final hasBattery = _batteryPercent != null && _batteryPercent! >= 0;
    return SizedBox(
      height: 220,
      child: BentoCard(
        borderRadius: 16,
        border: Border.all(color: const Color(0xFFB8D4F0)),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // العنوان في الأعلى
            const Text(
              'البطارية',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF181059),
              ),
            ),
            // مسافة حقيقية بين العنوان والمحتوى
            Expanded(
              child: Center(
                child: hasBattery
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              _batteryPercent! <= 20
                                  ? LucideIcons.batteryLow
                                  : LucideIcons.batteryFull,
                              color: accent,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$_batteryPercent%',
                            style: const TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF181059),
                            ),
                          ),
                        ],
                      )
                    : _buildUnavailableState(
                        LucideIcons.batteryWarning,
                        accent,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
