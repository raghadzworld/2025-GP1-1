import 'dart:math' show pi;

import 'package:flutter/material.dart';
import '../main.dart';
import '../widgets/custom_widgets.dart';

class _IntroPageData {
  final String? image;
  final IconData? icon;
  final double imageSize;
  final double rotationDegrees;
  final String title;
  final String subtitle;

  const _IntroPageData({
    this.image,
    this.icon,
    this.imageSize = 220,
    this.rotationDegrees = 0,
    required this.title,
    required this.subtitle,
  });
}

const _introPages = [
  _IntroPageData(
    image: 'assets/images/logo_nabeeh.png',
    imageSize: 320,
    title: 'مرحباً بك في نبيه',
    subtitle: 'رفيقك الذكي في كل لحظة',
  ),
  _IntroPageData(
    image: 'assets/images/wearableNABEEH.png',
    imageSize: 320,
    rotationDegrees: 15,
    title: 'السوار الذكي',
    subtitle: 'تواصل فوري ومباشر معك أينما كنت',
  ),
];

/// شاشة الانترو اللي تفتح بعد السبلاش — صفحتين بالتمرير (لوقو نبيه
/// ثم السوار الذكي) مع سهم دائري ينقل بينهم وأخيرًا لشاشة الترحيب.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onArrowTap() {
    if (_currentPage < _introPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: NabeehBubbleBackground()),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _introPages.length,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      itemBuilder: (context, i) =>
                          _buildPageContent(_introPages[i]),
                    ),
                  ),

                  // ── مؤشر الصفحة والسهم ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Row(
                      children: [
                        for (var i = 0; i < _introPages.length; i++) ...[
                          if (i != 0) const SizedBox(width: 6),
                          _buildPageDot(active: i == _currentPage),
                        ],
                        const Spacer(),
                        _buildArrowButton(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(_IntroPageData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 600;
        final imageSize = isCompact
            ? (constraints.maxHeight * 0.42).clamp(150.0, data.imageSize)
            : data.imageSize;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: isCompact ? 12 : 36),

        if (data.image != null)
          Transform.rotate(
            angle: data.rotationDegrees * (pi / 180),
            child: Image.asset(
              data.image!,
              width: imageSize,
              height: imageSize,
              fit: BoxFit.contain,
            ),
          )
        else
          Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Icon(data.icon, size: imageSize * 0.5, color: Colors.white),
          ),

        SizedBox(height: isCompact ? 16 : 36),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white60,
                  height: 1.9,
                ),
              ),
            ],
          ),
        ),

                SizedBox(height: isCompact ? 20 : 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageDot({required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: active ? 1 : 0.35),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildArrowButton() {
    return GestureDetector(
      onTap: _onArrowTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: const Icon(
          Icons.arrow_forward,
          color: Color(0xFF1a1760),
          size: 26,
        ),
      ),
    );
  }
}
