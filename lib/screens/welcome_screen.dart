import 'package:flutter/material.dart';
import '../main.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulse1Controller;
  late AnimationController _wave1Controller;
  late AnimationController _wave2Controller;
  late AnimationController _wave3Controller;
  late AnimationController _wave4Controller;

  late Animation<double> _pulseAnim;
  late Animation<Offset> _wave1Anim;
  late Animation<Offset> _wave2Anim;
  late Animation<Offset> _wave3Anim;
  late Animation<Offset> _wave4Anim;

  @override
  void initState() {
    super.initState();

    _pulse1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _wave1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _wave2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _wave3Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    _wave4Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.55, end: 0.9).animate(
      CurvedAnimation(parent: _pulse1Controller, curve: Curves.easeInOut),
    );

    _wave1Anim = Tween<Offset>(begin: Offset.zero, end: const Offset(12, -20))
        .animate(
          CurvedAnimation(parent: _wave1Controller, curve: Curves.easeInOut),
        );
    _wave2Anim = Tween<Offset>(begin: Offset.zero, end: const Offset(-14, 16))
        .animate(
          CurvedAnimation(parent: _wave2Controller, curve: Curves.easeInOut),
        );
    _wave3Anim = Tween<Offset>(begin: Offset.zero, end: const Offset(10, -12))
        .animate(
          CurvedAnimation(parent: _wave3Controller, curve: Curves.easeInOut),
        );
    _wave4Anim = Tween<Offset>(begin: Offset.zero, end: const Offset(-8, 10))
        .animate(
          CurvedAnimation(parent: _wave4Controller, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _pulse1Controller.dispose();
    _wave1Controller.dispose();
    _wave2Controller.dispose();
    _wave3Controller.dispose();
    _wave4Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            Container(color: const Color(0xFF1a1760)),

            _buildAnimatedCircle(
              _wave1Anim,
              -80,
              -30,
              380,
              const Color(0xFF6AB8F0),
              0.6,
            ),
            _buildAnimatedCircle(
              _wave2Anim,
              160,
              -220,
              420,
              const Color(0xFF5080D8),
              0.65,
            ),
            _buildAnimatedCircle(
              _wave3Anim,
              320,
              -10,
              340,
              const Color(0xFF6AB8F0),
              0.6,
            ),
            _buildAnimatedCircle(
              _wave4Anim,
              -100,
              190,
              280,
              const Color(0xFFAADDF5),
              0.55,
            ),
            _buildAnimatedCircle(
              _wave1Anim,
              130,
              230,
              260,
              const Color(0xFFD0EEFA),
              0.5,
            ),
            _buildAnimatedCircle(
              _wave2Anim,
              20,
              290,
              220,
              const Color(0xFF7BBDE0),
              0.5,
            ),
            _buildAnimatedCircle(
              _wave3Anim,
              550,
              -60,
              280,
              const Color(0xFFAADDF5),
              0.55,
            ),
            _buildAnimatedCircle(
              _wave4Anim,
              480,
              250,
              300,
              const Color(0xFF6AB8F0),
              0.6,
            ),
            _buildAnimatedCircle(
              _wave1Anim,
              600,
              180,
              240,
              const Color(0xFFD0EEFA),
              0.5,
            ),
            _buildAnimatedCircle(
              _wave2Anim,
              520,
              -20,
              200,
              const Color(0xFF7BBDE0),
              0.5,
            ),
            _buildAnimatedCircle(
              _wave3Anim,
              650,
              280,
              220,
              const Color(0xFFAADDF5),
              0.45,
            ),
            _buildAnimatedCircle(
              _wave4Anim,
              700,
              50,
              260,
              const Color(0xFF6AB8F0),
              0.5,
            ),

            SafeArea(
              child: Column(
                children: [
                  // ── زر لغة الإشارة ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(left: 20, top: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF181059),
                              Color(0xFF181059),
                              Color(0xFF1773CF),
                            ],
                            stops: [0.0, 0.30, 1.0],
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
                    ),
                  ),

                  const Spacer(),

                  // ── شعار نبيه ───────────────────────────────────────────
                  Image.asset(
                    'assets/images/logo_nabeeh.png',
                    width: 280,
                    height: 280,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),

                  // ── النص ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'مرحباً بك',
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFFFD350),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'رفيقك الذكي في كل لحظة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
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

                  const SizedBox(height: 60),

                  // ─── الأزرار ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        // ── زر إنشاء حساب ───────────────────────────────
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
                            onPressed: () =>
                                Navigator.pushNamed(context, '/signup'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.account_circle_outlined,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'إنشاء حساب',
                                  style: TextStyle(
                                    fontFamily: 'IBMPlexSansArabic',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ── فاصل "أو" ─────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  'أو',
                                  style: TextStyle(
                                    fontFamily: 'IBMPlexSansArabic',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── زر تسجيل الدخول ──────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, AppRoutes.login),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.login,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    fontFamily: 'IBMPlexSansArabic',
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildAnimatedCircle(
    Animation<Offset> animation,
    double top,
    double left,
    double size,
    Color color,
    double opacity,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Positioned(
          top: top + animation.value.dy,
          left: left + animation.value.dx,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: opacity),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
