import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _wave1Controller;
  late AnimationController _wave2Controller;
  late AnimationController _wave3Controller;
  late AnimationController _wave4Controller;

  late Animation<Offset> _wave1Anim;
  late Animation<Offset> _wave2Anim;
  late Animation<Offset> _wave3Anim;
  late Animation<Offset> _wave4Anim;

  bool _obscurePassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _rememberMe = false;
  String _emailError = '';
  String _passwordError = '';

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
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
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) {
        setState(
          () => _passwordError = _passwordController.text.isEmpty
              ? 'كلمة المرور مطلوبة'
              : '',
        );
      }
    });
  }

  @override
  void dispose() {
    _wave1Controller.dispose();
    _wave2Controller.dispose();
    _wave3Controller.dispose();
    _wave4Controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    if (rememberMe) {
      final savedEmail = prefs.getString('saved_email') ?? '';
      setState(() {
        _rememberMe = rememberMe;
        _emailController.text = savedEmail;
      });
    }
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

  Future<void> _login() async {
    _validateEmail(_emailController.text);
    setState(
      () => _passwordError = _passwordController.text.isEmpty
          ? 'كلمة المرور مطلوبة'
          : '',
    );

    if (_emailError.isNotEmpty || _passwordError.isNotEmpty) return;

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('remember_me', true);
        await prefs.setString('saved_email', _emailController.text.trim());
      } else {
        await prefs.remove('remember_me');
        await prefs.remove('saved_email');
      }
      if (mounted) {
        String welcomeName = '';
        try {
          final doc = await FirebaseFirestore.instance
              .collection('User')
              .doc(credential.user!.uid)
              .get();
          welcomeName = doc.data()?['FullName'] ?? '';
        } catch (_) {}
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.main,
            arguments: {'welcomeName': welcomeName},
          );
        }
      }
    } on FirebaseAuthException {
      if (mounted) {
        FocusScope.of(context).unfocus();
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'البريد الإلكتروني أو كلمة المرور غير صحيحة، يرجى التحقق والمحاولة مجدداً',
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
                          child: CustomPaint(painter: _LoginTopWavePainter()),
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
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'تسـجيـــل الدخــول',
                                  style: TextStyle(
                                    fontFamily: 'IBMPlexSansArabic',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF181059),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                _buildInputField(
                                  hint: 'البريد الإلكتروني',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  controller: _emailController,
                                  focusNode: _emailFocus,
                                  onChanged: (val) => _validateEmail(val),
                                ),
                                _buildErrorText(_emailError),
                                const SizedBox(height: 11),

                                _buildInputField(
                                  hint: 'كلمة المرور',
                                  icon: Icons.lock_outline_rounded,
                                  obscure: _obscurePassword,
                                  controller: _passwordController,
                                  focusNode: _passwordFocus,
                                  onToggleObscure: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  onChanged: (val) => setState(
                                    () => _passwordError = val.isEmpty
                                        ? 'كلمة المرور مطلوبة'
                                        : '',
                                  ),
                                ),
                                _buildErrorText(_passwordError),
                                const SizedBox(height: 6),

                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _rememberMe = !_rememberMe,
                                      ),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          gradient: _rememberMe
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xFF181059),
                                                    Color(0xFF1773CF),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          color: _rememberMe
                                              ? null
                                              : Colors.transparent,
                                          border: _rememberMe
                                              ? null
                                              : Border.all(
                                                  color: const Color(
                                                    0xFF181059,
                                                  ),
                                                  width: 1.5,
                                                ),
                                        ),
                                        child: _rememberMe
                                            ? const Icon(
                                                Icons.check_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'تذكــرنـــي',
                                      style: TextStyle(
                                        fontFamily: 'IBMPlexSansArabic',
                                        fontSize: 14,
                                        color: Color(0xFF181059),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: GestureDetector(
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      AppRoutes.forgotPassword,
                                    ),
                                    child: const Text(
                                      'هل نسيـت كلمــة المـرور؟ ',
                                      style: TextStyle(
                                        fontFamily: 'IBMPlexSansArabic',
                                        fontSize: 15,
                                        color: Color(0xFF1773CF),
                                        decoration: TextDecoration.underline,
                                        decorationColor: Color(0xFF1773CF),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF181059),
                                        Color(0xFF1773CF),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: TextButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const CircularProgressIndicator(
                                            color: Colors.white,
                                          )
                                        : const Text(
                                            'تسـجيــل الدخـــول',
                                            style: TextStyle(
                                              fontFamily: 'IBMPlexSansArabic',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        ' ليس لديــك حسـاب؟ ',
                                        style: TextStyle(
                                          fontFamily: 'IBMPlexSansArabic',
                                          fontSize: 13,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.pushNamed(
                                          context,
                                          '/signup',
                                        ),
                                        child: const Text(
                                          'إنشــاء حســاب',
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
                            ),
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
                                  painter: _LoginBottomWavePainter(),
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
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscure,
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
        prefixIcon: onToggleObscure != null
            ? IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF9CA3AF),
                  size: 18,
                ),
              )
            : null,
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

class _LoginTopWavePainter extends CustomPainter {
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
  bool shouldRepaint(_LoginTopWavePainter oldDelegate) => false;
}

class _LoginBottomWavePainter extends CustomPainter {
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
  bool shouldRepaint(_LoginBottomWavePainter oldDelegate) => false;
}
