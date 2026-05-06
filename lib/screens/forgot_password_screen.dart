import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  late AnimationController _wave1Controller;
  late AnimationController _wave2Controller;
  late AnimationController _wave3Controller;
  late AnimationController _wave4Controller;

  late Animation<Offset> _wave1Anim;
  late Animation<Offset> _wave2Anim;
  late Animation<Offset> _wave3Anim;
  late Animation<Offset> _wave4Anim;

  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();

  bool _isLoading = false;
  bool _emailSent = false;
  String _emailError = '';

  int _countdown = 15;
  Timer? _countdownTimer;

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

    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _validateEmail(_emailController.text);
    });
  }

  @override
  void dispose() {
    _wave1Controller.dispose();
    _wave2Controller.dispose();
    _wave3Controller.dispose();
    _wave4Controller.dispose();
    _emailController.dispose();
    _emailFocus.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _validateEmail(String val) {
    setState(() {
      _emailError = val.trim().isEmpty
          ? 'البريد الإلكتروني مطلوب'
          : !RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(val.trim())
          ? 'صيغة البريد الإلكتروني غير صحيحة'
          : '';
    });
  }

  void _startCountdown() {
    _countdown = 15;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    });
  }

  Future<void> _sendResetEmail() async {
    _validateEmail(_emailController.text);
    if (_emailError.isNotEmpty) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        setState(() => _emailSent = true);
        _startCountdown();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'user-not-found') {
          FocusScope.of(context).unfocus();
          await Future.delayed(const Duration(milliseconds: 200));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'لا يوجد حساب مرتبط بهذا البريد الإلكتروني',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else {
          setState(() => _emailSent = true);
          _startCountdown();
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                            onTap: () => Navigator.pop(context),
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
                          child: CustomPaint(painter: _ForgotTopWavePainter()),
                        ),
                      ),

                      // ── المحتوى الرئيسي ──
                      Positioned(
                        top: 80,
                        left: 0,
                        right: 0,
                        bottom: 130,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 80, 24, 20),
                            child: _emailSent
                                ? _buildSuccessView()
                                : _buildFormView(),
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
                                  painter: _ForgotBottomWavePainter(),
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

  // ── واجهة الفورم ──
  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'استعـادة كلمـة المـرور',
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF181059),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين',
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 24),
        _buildInputField(
          hint: 'البريد الإلكتروني',
          icon: Icons.email_outlined,
          controller: _emailController,
          focusNode: _emailFocus,
          onChanged: (val) => _validateEmail(val),
        ),
        _buildErrorText(_emailError),
        const SizedBox(height: 28),
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
            onPressed: _isLoading ? null : _sendResetEmail,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'إرسال رابط الاستعادة',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFD350),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'تذكرت كلمة المرور؟ ',
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

  // ── واجهة النجاح ──
  Widget _buildSuccessView() {
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
                  color: Color(0xFF2E7D32),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'تم إرسال رابط الاستعادة!',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF181059),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'أرسلنا رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني، تحقق منه',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 13,
                  color: Color(0xFF6B7280),
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
              const SizedBox(height: 18),

              // ── العداد التنازلي ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF1773CF).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: _countdown / 15,
                            strokeWidth: 3,
                            backgroundColor: const Color(0xFFD1D5DB),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF1773CF),
                            ),
                          ),
                          Center(
                            child: Text(
                              '$_countdown',
                              style: const TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1773CF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'سيتم تحويلك لصفحة تسجيل الدخول تلقائياً...',
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorText(String error) {
    if (error.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 4),
      child: Row(
        children: [
          const Icon(Icons.cancel_rounded, size: 16, color: Colors.red),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.emailAddress,
      textDirection: TextDirection.rtl,
      onChanged: onChanged,
      style: const TextStyle(
        fontFamily: 'IBMPlexSansArabic',
        fontSize: 14,
        color: Color(0xFF181059),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 14,
          color: Color(0xFF9CA3AF),
        ),
        suffixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 18),
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1773CF), width: 1.5),
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

class _ForgotTopWavePainter extends CustomPainter {
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
  bool shouldRepaint(_ForgotTopWavePainter oldDelegate) => false;
}

class _ForgotBottomWavePainter extends CustomPainter {
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
  bool shouldRepaint(_ForgotBottomWavePainter oldDelegate) => false;
}
