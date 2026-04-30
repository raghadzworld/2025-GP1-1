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
  final String _deviceName = 'LILYGO Watch';

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
        // العنوان
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              'معلومات الساعة',
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

  Widget _buildWatchHeroCard() {
    return BentoCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 16,
      border: Border.all(color: const Color.fromARGB(255, 235, 233, 229)),
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
                    /*const Text(
                      'الساعة المتصلة',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF181059),
                      ),
                    )*/
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
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.18),
                ),
              ),
              child: const Text(
                'غير متصل',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
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
      borderRadius: 16,
      border: Border.all(color: const Color.fromARGB(255, 235, 233, 229)),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          // العنوان في الأعلى
          const Align(
            alignment: Alignment.topCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'آخر تزامن',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF181059),
                  ),
                ),
                Icon(
                  LucideIcons.refreshCcw,
                  color: NabeehColors.gray,
                  size: 18,
                ),
              ],
            ),
          ),
          // المحتوى في المنتصف
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'غير متاح',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey,
                    height: 1,
                  ),
                ),
                SizedBox(height: 8),
                Icon(
                  LucideIcons.wifiOff,
                  color: Colors.grey,
                  size: 28,
                ),
              ],
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
      borderRadius: 16,
      border: Border.all(color: const Color.fromARGB(255, 235, 233, 229)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'البطارية',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF181059),
                ),
              ),
              Icon(
                LucideIcons.battery,
                color: Colors.green,
                size: 18,
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Center(
            child: Text(
              '--',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 34,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
              ),
            ),
          ),

          const SizedBox(height: 6),

          const Center(
            child: Text(
              'غير متاح',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 8,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
              ),
            ),
          ),

          const SizedBox(height: 18),

          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: NabeehColors.slate100,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    ),
  );
}}
