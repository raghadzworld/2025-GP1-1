import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../services/email_service.dart';

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

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _passwordFieldFocused = false;

  String _passwordStrength = '';
  Color _passwordStrengthColor = Colors.transparent;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _isLoading = false;
  String _confirmPasswordStatus = '';
  String _nameError = '';
  String _emailError = '';
  String _passwordError = '';

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

    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _validateName(_nameController.text);
    });
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _validateEmail(_emailController.text);
    });
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) _validatePassword(_passwordController.text);
    });
    _confirmPasswordFocus.addListener(() {
      if (!_confirmPasswordFocus.hasFocus) {
        if (_confirmPasswordController.text.isEmpty) {
          setState(() => _confirmPasswordStatus = 'empty');
        }
      }
    });
  }

  @override
  void dispose() {
    _wave1Controller.dispose();
    _wave2Controller.dispose();
    _wave3Controller.dispose();
    _wave4Controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  // ✅ يحدث تأكيد كلمة المرور تلقائياً لما يتغير الباسورد
  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = '';
        _passwordStrengthColor = Colors.transparent;
        if (_confirmPasswordController.text.isNotEmpty) {
          _confirmPasswordStatus = 'nomatch';
        }
      });
      return;
    }
    bool hasUpper = password.contains(RegExp(r'[A-Z]'));
    bool hasLower = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#\$&*~%^]'));
    bool hasLength = password.length >= 8;
    int score = [
      hasUpper,
      hasLower,
      hasDigit,
      hasSpecial,
      hasLength,
    ].where((e) => e).length;
    setState(() {
      if (score <= 2) {
        _passwordStrength = 'ضعيفة';
        _passwordStrengthColor = Colors.red;
      } else if (score == 3 || score == 4) {
        _passwordStrength = 'متوسطة';
        _passwordStrengthColor = Colors.orange;
      } else {
        _passwordStrength = 'قوية';
        _passwordStrengthColor = Colors.green;
      }

      // تحديث تأكيد كلمة المرور تلقائياً
      if (_confirmPasswordController.text.isNotEmpty) {
        _confirmPasswordStatus = _confirmPasswordController.text == password
            ? 'match'
            : 'nomatch';
      }
    });
  }

  void _validateName(String val) {
    setState(() {
      _nameError = val.trim().isEmpty ? 'الاسم الكامل مطلوب' : '';
    });
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

  void _validatePassword(String val) {
    setState(() {
      _passwordError = val.isEmpty
          ? 'كلمة المرور مطلوبة'
          : val.length < 8
          ? 'كلمة المرور يجب أن تكون 8 خانات على الأقل'
          : !val.contains(RegExp(r'[A-Z]'))
          ? 'يجب أن تحتوي على حرف كبير'
          : !val.contains(RegExp(r'[a-z]'))
          ? 'يجب أن تحتوي على حرف صغير'
          : !val.contains(RegExp(r'[0-9]'))
          ? 'يجب أن تحتوي على رقم'
          : !val.contains(RegExp(r'[!@#\$&*~%^]'))
          ? 'يجب أن تحتوي على رمز'
          : '';
    });
  }

  Future<void> _signUp() async {
    _validateName(_nameController.text);
    _validateEmail(_emailController.text);
    _validatePassword(_passwordController.text);

    if (_nameError.isNotEmpty ||
        _emailError.isNotEmpty ||
        _passwordError.isNotEmpty)
      return;

    if (_confirmPasswordController.text.isEmpty) {
      setState(() => _confirmPasswordStatus = 'empty');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _confirmPasswordStatus = 'nomatch');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      await FirebaseFirestore.instance
          .collection('User')
          .doc(credential.user!.uid)
          .set({
            'FullName': _nameController.text.trim(),
            'Email': _emailController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });

      try {
        await EmailService.sendWelcomeEmail(
          _emailController.text.trim(),
          _nameController.text.trim(),
        );
      } catch (_) {}

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.main,
          arguments: {
            'welcomeName': _nameController.text.trim(),
            'isNewUser': true,
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        setState(() => _emailError = 'البريد الإلكتروني مستخدم مسبقاً');
      } else if (e.code == 'invalid-email') {
        setState(() => _emailError = 'البريد الإلكتروني غير صحيح');
      } else if (e.code == 'weak-password') {
        setState(() => _passwordError = 'كلمة المرور ضعيفة جداً');
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('حدث خطأ، حاولي مرة أخرى')),
          );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final password = _passwordController.text;

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
                          child: CustomPaint(painter: _TopWavePainter()),
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
                                  controller: _nameController,
                                  focusNode: _nameFocus,
                                  onChanged: _validateName,
                                ),
                                _buildErrorText(_nameError),
                                const SizedBox(height: 11),

                                _buildInputField(
                                  hint: 'البريد الإلكتروني',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  controller: _emailController,
                                  focusNode: _emailFocus,
                                  onChanged: _validateEmail,
                                ),
                                _buildErrorText(_emailError),
                                const SizedBox(height: 11),

                                // حقل كلمة المرور
                                Focus(
                                  onFocusChange: (hasFocus) {
                                    setState(
                                      () => _passwordFieldFocused = hasFocus,
                                    );
                                    if (!hasFocus)
                                      _validatePassword(
                                        _passwordController.text,
                                      );
                                  },
                                  child: _buildInputField(
                                    hint: 'كلمة المرور',
                                    icon: Icons.lock_outline_rounded,
                                    obscure: _obscurePassword,
                                    controller: _passwordController,
                                    focusNode: _passwordFocus,
                                    onToggleObscure: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    onChanged: (val) {
                                      _checkPasswordStrength(val);
                                      _validatePassword(val);
                                    },
                                  ),
                                ),

                                if (_passwordFieldFocused)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 10,
                                      right: 4,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'قوة كلمة المرور: ',
                                              style: TextStyle(
                                                fontFamily: 'IBMPlexSansArabic',
                                                fontSize: 12,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                            if (_passwordStrength.isNotEmpty)
                                              Text(
                                                _passwordStrength,
                                                style: TextStyle(
                                                  fontFamily:
                                                      'IBMPlexSansArabic',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: _passwordStrengthColor,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            _buildStrengthBar(
                                              _passwordStrength == 'ضعيفة' ||
                                                  _passwordStrength ==
                                                      'متوسطة' ||
                                                  _passwordStrength == 'قوية',
                                            ),
                                            const SizedBox(width: 4),
                                            _buildStrengthBar(
                                              _passwordStrength == 'متوسطة' ||
                                                  _passwordStrength == 'قوية',
                                            ),
                                            const SizedBox(width: 4),
                                            _buildStrengthBar(
                                              _passwordStrength == 'قوية',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        _buildRequirement(
                                          '8 خانات على الأقل',
                                          password.length >= 8,
                                        ),
                                        _buildRequirement(
                                          'حرف كبير (A-Z)',
                                          password.contains(RegExp(r'[A-Z]')),
                                        ),
                                        _buildRequirement(
                                          'حرف صغير (a-z)',
                                          password.contains(RegExp(r'[a-z]')),
                                        ),
                                        _buildRequirement(
                                          'رقم (0-9)',
                                          password.contains(RegExp(r'[0-9]')),
                                        ),
                                        _buildRequirement(
                                          'رمز (!@#\$&*~%^)',
                                          password.contains(
                                            RegExp(r'[!@#\$&*~%^]'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                _buildErrorText(_passwordError),
                                const SizedBox(height: 11),

                                // ✅ حقل تأكيد كلمة المرور
                                _buildInputField(
                                  hint: 'تأكيد كلمة المرور',
                                  icon: Icons.lock_outline_rounded,
                                  obscure: _obscureConfirmPassword,
                                  controller: _confirmPasswordController,
                                  focusNode: _confirmPasswordFocus,
                                  onToggleObscure: () => setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val.isEmpty) {
                                        _confirmPasswordStatus = 'empty';
                                      } else if (val ==
                                          _passwordController.text) {
                                        _confirmPasswordStatus = 'match';
                                      } else {
                                        _confirmPasswordStatus = 'nomatch';
                                      }
                                    });
                                  },
                                ),

                                if (_confirmPasswordStatus == 'match' &&
                                    _confirmPasswordFocus.hasFocus)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      right: 4,
                                    ),
                                    child: Row(
                                      children: const [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 16,
                                          color: Colors.green,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'كلمة المرور متطابقة',
                                          style: TextStyle(
                                            fontFamily: 'IBMPlexSansArabic',
                                            fontSize: 12,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_confirmPasswordStatus == 'nomatch')
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      right: 4,
                                    ),
                                    child: Row(
                                      children: const [
                                        Icon(
                                          Icons.cancel_rounded,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'كلمة المرور غير متطابقة',
                                          style: TextStyle(
                                            fontFamily: 'IBMPlexSansArabic',
                                            fontSize: 12,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_confirmPasswordStatus == 'empty')
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      right: 4,
                                    ),
                                    child: Row(
                                      children: const [
                                        Icon(
                                          Icons.cancel_rounded,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'تأكيد كلمة المرور مطلوب',
                                          style: TextStyle(
                                            fontFamily: 'IBMPlexSansArabic',
                                            fontSize: 12,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
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
                                    onPressed: _isLoading ? null : _signUp,
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
                                            'إنشـــــاء حســاب',
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

  Widget _buildRequirement(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: met ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 12,
              color: met ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthBar(bool active) {
    return Expanded(
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: active ? _passwordStrengthColor : const Color(0xFFE5E7EB),
        ),
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

class _TopWavePainter extends CustomPainter {
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
