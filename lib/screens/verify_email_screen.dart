import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../main.dart';
import '../services/email_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final String displayName;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.displayName = '',
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with TickerProviderStateMixin {
  late AnimationController _wave1Controller;
  late AnimationController _wave2Controller;
  late AnimationController _wave3Controller;
  late AnimationController _wave4Controller;

  late Animation<Offset> _wave1Anim;
  late Animation<Offset> _wave2Anim;
  late Animation<Offset> _wave3Anim;
  late Animation<Offset> _wave4Anim;

  bool _isResending = false;
  bool _resendSuccess = false;
  String _resendError = '';

  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _wave1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
    _wave2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
    _wave3Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _wave4Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat(reverse: true);

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

    // ✅ نبدأ العد التنازلي فور دخول الصفحة، لأن رسالة تفعيل أولى
    // انبعثت أصلاً وقت الساين أب (أو محاولة الدخول)
    _startCooldown();
  }

  @override
  void dispose() {
    _wave1Controller.dispose();
    _wave2Controller.dispose();
    _wave3Controller.dispose();
    _wave4Controller.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldown = 60;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  Future<void> _resendVerification() async {
    setState(() {
      _isResending = true;
      _resendError = '';
    });

    try {
      await EmailService.sendWelcomeVerifyEmail(
        widget.email,
        widget.displayName,
      );
      if (mounted) {
        setState(() => _resendSuccess = true);
        _startCooldown();
      }
    } on FirebaseFunctionsException catch (_) {
      if (mounted) {
        setState(() {
          _resendError = 'تعذّر إرسال الرابط، حاولي مرة أخرى بعد قليل';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _resendError = 'تعذّر إرسال الرابط، حاولي مرة أخرى');
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF1a1760),
      body: Stack(
        children: [
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

          SafeArea(
            child: Column(
              children: [
                // شريط علوي
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: SizedBox(
                    height: 50,
                    child: Stack(
                      children: [
                        Align(
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.welcome,
                              (route) => false,
                            ),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 80,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(color: Colors.white),
                      ),

                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SizedBox(
                          width: screenWidth,
                          height: 100,
                          child: CustomPaint(painter: _VerifyTopWavePainter()),
                        ),
                      ),

                      Positioned(
                        top: 80,
                        left: 0,
                        right: 0,
                        bottom: 130,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 80, 24, 20),
                            child: _buildContent(),
                          ),
                        ),
                      ),

                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: SizedBox(
                          height: 130,
                          child: Stack(
                            children: [
                              SizedBox(
                                width: screenWidth,
                                height: 130,
                                child: CustomPaint(
                                  painter: _VerifyBottomWavePainter(),
                                ),
                              ),
                              _buildAnimatedCircle(
                                _wave2Anim,
                                20,
                                -50,
                                220,
                                const Color(0xFF6AB8F0),
                                0.5,
                              ),
                              _buildAnimatedCircle(
                                _wave3Anim,
                                30,
                                200,
                                200,
                                const Color(0xFFAADDF5),
                                0.45,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF181059),
                      Color(0xFF181059),
                      Color(0xFF1773CF),
                    ],
                    stops: [0.0, 0.30, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'يرجى تفعيل بريدك الإلكتروني',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF181059),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'أرسلنا رابط تفعيل إلى ',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF181059),
                      ),
                    ),
                    const TextSpan(
                      text: '، يرجى الضغط على الرابط قبل تسجيل الدخول',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'إذا لم تجد الرسالة، تحقق من مجلد البريد غير المرغوب فيه',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_resendSuccess) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2E7D32)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Color(0xFF2E7D32),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تم إرسال رابط تفعيل جديد إلى بريدك',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_resendError.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF4D4D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: Color(0xFFD32F2F),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _resendError,
                          style: const TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD32F2F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),

              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: (_isResending || _cooldown > 0)
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF181059), Color(0xFF1773CF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: (_isResending || _cooldown > 0)
                      ? const Color(0xFFE5E7EB)
                      : null,
                ),
                child: TextButton(
                  onPressed: (_isResending || _cooldown > 0)
                      ? null
                      : _resendVerification,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isResending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _cooldown > 0
                              ? 'إعادة الإرسال بعد $_cooldown ثانية'
                              : 'إعادة إرسال رابط التفعيل',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _cooldown > 0
                                ? const Color(0xFF9CA3AF)
                                : Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'تم تفعيل البريد؟ ',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
              GestureDetector(
                onTap: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.login),
                child: const Text(
                  'سجّل دخولك',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1773CF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

class _VerifyTopWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, 0);
    path.cubicTo(
      size.width * 0.25,
      size.height * 0.001,
      size.width * 0.75,
      size.height * 1.8,
      size.width,
      0,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_VerifyTopWavePainter oldDelegate) => false;
}

class _VerifyBottomWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1a1760)
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.cubicTo(
      size.width * 0.3,
      0,
      size.width * 0.65,
      size.height * 0.7,
      size.width,
      size.height * 0.3,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_VerifyBottomWavePainter oldDelegate) => false;
}
