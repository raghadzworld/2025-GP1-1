import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../widgets/custom_widgets.dart';
import 'nabeeh_colors.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  bool _isConnected = true;
  String _deviceName = 'LILYGO Watch ';
  int _batteryLevel = 84;
  DateTime _lastSync = DateTime.now();
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _lastSync = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  String _getFormattedSyncTime() {
    final now = DateTime.now();
    final difference = now.difference(_lastSync);
    if (difference.inSeconds < 60) return 'الآن';
    if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} دقيقة';
    if (difference.inHours < 24) return 'منذ ${difference.inHours} ساعة';
    return 'منذ ${difference.inDays} يوم';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
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
          ],
        ),
      ),
    );
  }

  // ─── Custom Header ──────────────────────────────────────────────────────────
Widget _buildHeader(BuildContext context) {
  return Container(
    padding: const EdgeInsets.only(top: 52, bottom: 20, right: 20, left: 20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFB8D4F0), Color(0xFFFFFFFF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: Row(
      children: [
        // تم حذف زر الرجوع بالكامل من هنا
        // وضعنا مساحة فارغة للحفاظ على التوازن
        const SizedBox(width: 50),
        
        // العنوان
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'معلومات الساعة',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: NabeehColors.dark,
                letterSpacing: -1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        
        // أيقونة لغة الإشارة
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF181059), Color(0xFF181059), Color(0xFF1773CF)],
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
            padding: const EdgeInsets.all(12),
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

  Widget _buildWatchHeroCard() {
    return BentoCard(
      padding: const EdgeInsets.all(24),
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
                    const Text(
                      'الساعة المتصلة',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: NabeehColors.slate400,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _deviceName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: NabeehColors.dark,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 👇 Watch icon – EXACT match from HomeScreen
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF1F1F1), Color(0xFFF3F3F3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF9F9F9F)),
                ),
                child: const Icon(
                  Icons.watch_rounded,
                  color: NabeehColors.darkBlue,
                  size: 24,
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
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD350), Color(0xFF1773CF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: NabeehColors.accent.withValues(alpha: 0.18),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scale(
                      begin: const Offset(0.95, 0.95),
                      end: const Offset(1.05, 1.05),
                      duration: 2500.ms,
                    ),
                Container(
                  width: 194,
                  height: 194,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                 color: NabeehColors.slate50
                  ),
                ),
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NabeehColors.slate50.withValues(alpha: 0.7),
                  ),
                  // 👇 Using the same watch icon inside the circle
                  child: const Icon(
                    Icons.watch_rounded,
                    size: 80,
                    color: NabeehColors.darkBlue,
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
                color: _isConnected
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isConnected
                      ? Colors.green.withValues(alpha: 0.18)
                      : Colors.grey.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                _isConnected ? 'متصل' : 'غير متصل',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: _isConnected ? Colors.green : Colors.grey,
                  letterSpacing: 2,
                ),
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

Widget _buildSyncCard() {
  return SizedBox(
    height: 200,
    child: BentoCard(
      border: Border.all(width: 0.8, color: NabeehColors.cardBorder),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'آخر تزامن',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.slate400,
                  letterSpacing: 2,
                ),
              ),
              Icon(
                LucideIcons.refreshCcw,
                color: NabeehColors.gray,
                size: 18,
              ),
            ],
          ),

          const SizedBox(height: 16),

          Center(
            child: Text(
              _getFormattedSyncTime(),
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: NabeehColors.dark,
                height: 1.1,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: Icon(
              LucideIcons.checkCircle2,
              color: NabeehColors.green,
              size: 28,
            )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(
                  duration: 1500.ms,
                  color: NabeehColors.background,
                ),
          ),
        ],
      ),
    ),
  );
}

 Widget _buildBatteryCard() {
  return SizedBox(
    height: 200,
    child: BentoCard(
      border: Border.all(width: 0.8, color: NabeehColors.cardBorder),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                LucideIcons.battery,
                color: Colors.green,
                size: 18,
              ),
              Text(
                'البطارية',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.slate400,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Center(
            child: Text(
              '$_batteryLevel%',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: NabeehColors.dark,
              ),
            ),
          ),

          const SizedBox(height: 6),

          Center(
            child: Text(
              _batteryLevel > 20 ? 'حالة جيدة' : 'منخفضة',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: NabeehColors.slate400,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 🔋 progress bar
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: NabeehColors.slate100,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerRight,
              widthFactor: _batteryLevel / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: _batteryLevel > 20
                      ? NabeehColors.green
                      : Colors.red,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}}
