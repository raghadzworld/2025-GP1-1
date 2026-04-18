import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/custom_widgets.dart';   // ← موجود الآن عندها
import 'Nabeeh_Colors.dart';       // ← موجود الآن عندها

class WatchScreen extends StatefulWidget {   // ← تغيير الاسم فقط
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  bool _isConnected = true;
  String _deviceName = 'Samsung Galaxy Watch 6';
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

  // ─── تم حذف دالة _navigateToTab لأنها لن تستخدم ──────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ─── تم حذف bottomNavigationBar: NabeehNavBar(...) ─────────────────
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 64),
            _buildHeader(context),
            const SizedBox(height: 32),
            _buildWatchVisual(),
            const SizedBox(height: 16),
            _buildMetricsGrid(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ─── جميع الدوال الباقية (_buildHeader, _buildWatchVisual, ...) ─────────
  //      تبقى كما هي تماماً بدون أي تغيير
  //      سأنسخها هنا للتوثيق، لكن فعلياً لا تحتاجين تعديلها

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الأجهزة المتصلة',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.slate400,
                  letterSpacing: 2,
                ),
              ),
              Text(
                _deviceName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.dark,
                  letterSpacing: -1,
                  height: 1.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NabeehColors.slate100),
                boxShadow: [
                  BoxShadow(
                    color: NabeehColors.dark.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(LucideIcons.arrowLeft, color: NabeehColors.dark, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchVisual() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: BentoCard(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            SizedBox(
              height: 240,
              width: double.infinity,
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
                          color: NabeehColors.accent.withValues(alpha: 0.2),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 2500.ms),
                  Container(
                    width: 194,
                    height: 194,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  ),
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NabeehColors.slate50.withValues(alpha: 0.5),
                    ),
                    child: const Icon(LucideIcons.watch, size: 80, color: NabeehColors.dark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isConnected
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isConnected
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.2),
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
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildSyncCard(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildBatteryCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncCard() {
    return BentoCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'اخر تزامن',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.dark,
                  letterSpacing: 1,
                ),
              ),
              Icon(LucideIcons.refreshCcw, color: NabeehColors.blue, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _getFormattedSyncTime(),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Icon(LucideIcons.checkCircle2, color: NabeehColors.green, size: 28)
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(duration: 1500.ms, color: NabeehColors.background),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryCard() {
    return BentoCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(LucideIcons.battery, color: Colors.green, size: 20),
              Text('البطارية', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: NabeehColors.slate400)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$_batteryLevel%', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: NabeehColors.dark)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _batteryLevel > 20 ? 'حالة جيدة' : 'منخفضة',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: NabeehColors.slate400),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(color: NabeehColors.slate100, borderRadius: BorderRadius.circular(3)),
            child: FractionallySizedBox(
              alignment: Alignment.centerRight,
              widthFactor: _batteryLevel / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: _batteryLevel > 20 ? NabeehColors.green : Colors.red,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: (_batteryLevel > 20 ? NabeehColors.green : Colors.red).withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
