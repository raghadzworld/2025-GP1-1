import 'package:flutter/material.dart';
import '../main.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  late AnimationController _wave1Controller;
  late AnimationController _wave2Controller;
  late AnimationController _wave3Controller;
  late AnimationController _wave4Controller;

  late Animation<Offset> _wave1Anim;
  late Animation<Offset> _wave2Anim;
  late Animation<Offset> _wave3Anim;
  late Animation<Offset> _wave4Anim;

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _wave1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _wave2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _wave3Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _wave4Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
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
  }

  @override
  void dispose() {
    _wave1Controller.dispose();
    _wave2Controller.dispose();
    _wave3Controller.dispose();
    _wave4Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
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
                // ── شريط العلوي ──────────────────────────────────────────
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

                // ─── المنطقة البيضاء بموجة علوية ─────────────────────────
                Expanded(
                  child: Stack(
                    children: [
                      // الأبيض الكامل من تحت الموجة
                      Positioned(
                        top: 80,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(color: Colors.white),
                      ),

                      // الموجة العلوية — نفس أسلوب الصورة
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SizedBox(
                          width: screenWidth,
                          height: 100,
                          child: CustomPaint(painter: _TopWavePainter()),
                        ),
                      ),

                      // المحتوى
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
                                  'إنشـاء حسـاب',
                                  style: TextStyle(
                                    fontFamily: 'IBMPlexSansArabic',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF181059),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _buildInputField(
                                  hint: 'الاسم الكامل',
                                  icon: Icons.person_outline_rounded,
                                ),
                                const SizedBox(height: 11),
                                _buildInputField(
                                  hint: 'البريد الإلكتروني',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 11),
                                _buildInputField(
                                  hint: 'رقم الجوال',
                                  icon: Icons.phone_android_rounded,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 11),
                                _buildInputField(
                                  hint: 'كلمة المرور',
                                  icon: Icons.lock_outline_rounded,
                                  obscure: _obscurePassword,
                                  onToggleObscure: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                                const SizedBox(height: 11),
                                _buildInputField(
                                  hint: 'تأكيد كلمة المرور',
                                  icon: Icons.lock_outline_rounded,
                                  obscure: _obscureConfirmPassword,
                                  onToggleObscure: () => setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: (v) => setState(
                                        () => _rememberMe = v ?? false,
                                      ),
                                      activeColor: const Color(0xFF1773CF),
                                      side: const BorderSide(
                                        color: Color(0xFF9CA3AF),
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _rememberMe = !_rememberMe,
                                      ),
                                      child: const Text(
                                        'تذكرنـــي',
                                        style: TextStyle(
                                          fontFamily: 'IBMPlexSansArabic',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,

                                          color: Color.fromARGB(
                                            255,
                                            17,
                                            58,
                                            134,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
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
                                    onPressed: () {},
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      'إنشـــــاء حســاب',
                                      style: TextStyle(
                                        fontFamily: 'IBMPlexSansArabic',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFFFD350),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Color(0xFFE5E7EB),
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Text(
                                        ' أو سجّــل بــــــ',
                                        style: TextStyle(
                                          fontFamily: 'IBMPlexSansArabic',
                                          fontSize: 12,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Color(0xFFE5E7EB),
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Center(
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                        width: 1.5,
                                      ),
                                      color: Colors.white,
                                    ),
                                    child: IconButton(
                                      onPressed: () {},
                                      icon: Image.asset(
                                        'assets/images/icon_google.png',
                                        width: 22,
                                        height: 22,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                              Icons.g_mobiledata_rounded,
                                              color: Color(0xFF4285F4),
                                              size: 28,
                                            ),
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
                                        'هل لديك حسـاب؟ ',
                                        style: TextStyle(
                                          fontFamily: 'IBMPlexSansArabic',
                                          fontSize: 13,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.pushNamed(
                                          context,
                                          AppRoutes.login,
                                        ),
                                        child: const Text(
                                          'سجّل دخولـــــك',
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

                      // الموجة السفلية
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
                                  painter: _BottomWavePainter(),
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

  Widget _buildInputField({
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      keyboardType: keyboardType,
      obscureText: obscure,
      textDirection: TextDirection.rtl,
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

// الموجة العلوية — تنحني من الأعلى للأسفل في المنتصف
class _TopWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path();
    // ابدأ من أعلى يسار
    path.moveTo(0, 0);
    // انحنِ للأسفل في المنتصف ثم ارجع للأعلى في اليمين
    path.cubicTo(
      size.width * 0.25,
      size.height * 0.001, // نقطة تحكم 1 — تنزل كثيراً
      size.width * 0.75,
      size.height * 1.8, // نقطة تحكم 2 — تبقى تحت
      size.width,
      0, // نهاية — أعلى يمين
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TopWavePainter oldDelegate) => false;
}

class _BottomWavePainter extends CustomPainter {
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
  bool shouldRepaint(_BottomWavePainter oldDelegate) => false;
}
