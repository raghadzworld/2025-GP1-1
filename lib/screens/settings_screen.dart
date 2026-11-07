import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'nabeeh_colors.dart';
import '../widgets/sign_language_box.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final currentPasswordCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();
  final repeatPasswordCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureRepeat = true;
  bool _isLoading = false;

  // --- رسائل الخطأ: نفس أسلوب وصياغة صفحة إنشاء الحساب ---
  String _currentPasswordError = '';
  String _passwordError = '';
  String _confirmPasswordStatus = ''; // '' | empty | match | nomatch
  bool _newPasswordFocused = false;
  bool _confirmPasswordFocused = false;

  static final _upperRe = RegExp(r'[A-Z]');
  static final _lowerRe = RegExp(r'[a-z]');
  static final _digitRe = RegExp(r'[0-9]');
  static final _specialRe = RegExp(r'[!@#\$&*~%^]');

  void _validateCurrentPassword(String val) {
    setState(() {
      _currentPasswordError = val.isEmpty ? 'كلمة المرور الحالية مطلوبة' : '';
    });
  }

  void _validatePassword(String val) {
    setState(() {
      _passwordError = val.isEmpty
          ? 'كلمة المرور مطلوبة'
          : val.length < 8
          ? 'كلمة المرور يجب أن تكون 8 خانات على الأقل'
          : !val.contains(_upperRe)
          ? 'يجب أن تحتوي على حرف كبير'
          : !val.contains(_lowerRe)
          ? 'يجب أن تحتوي على حرف صغير'
          : !val.contains(_digitRe)
          ? 'يجب أن تحتوي على رقم'
          : !val.contains(_specialRe)
          ? 'يجب أن تحتوي على رمز'
          : '';
    });
  }

  void _onNewPasswordChanged(String val) {
    _validatePassword(val);
    // تحديث حالة التأكيد تلقائياً لما تتغير كلمة المرور الجديدة
    if (repeatPasswordCtrl.text.isNotEmpty) {
      setState(() {
        _confirmPasswordStatus =
            repeatPasswordCtrl.text == val ? 'match' : 'nomatch';
      });
    }
  }

  void _onConfirmPasswordChanged(String val) {
    setState(() {
      if (val.isEmpty) {
        _confirmPasswordStatus = 'empty';
      } else if (val == newPasswordCtrl.text) {
        _confirmPasswordStatus = 'match';
      } else {
        _confirmPasswordStatus = 'nomatch';
      }
    });
  }

  /// عند الضغط على حفظ والبيانات ناقصة: نعرض كل الأخطاء مثل صفحة إنشاء الحساب
  void _showAllErrors() {
    _validateCurrentPassword(currentPasswordCtrl.text);
    _validatePassword(newPasswordCtrl.text);
    if (repeatPasswordCtrl.text.isEmpty) {
      setState(() => _confirmPasswordStatus = 'empty');
    } else if (repeatPasswordCtrl.text != newPasswordCtrl.text) {
      setState(() => _confirmPasswordStatus = 'nomatch');
    }
  }

  @override
  void dispose() {
    currentPasswordCtrl.dispose();
    newPasswordCtrl.dispose();
    repeatPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Live Validation Rules
    final newPass = newPasswordCtrl.text;
    final repeatPass = repeatPasswordCtrl.text;

    final bool hasMinLength = newPass.length >= 8;
    final bool hasUppercase = _upperRe.hasMatch(newPass);
    final bool hasLowercase = _lowerRe.hasMatch(newPass);
    final bool hasDigit = _digitRe.hasMatch(newPass);
    final bool hasSpecialChar = _specialRe.hasMatch(newPass);
    final bool passwordsMatch = newPass == repeatPass && repeatPass.isNotEmpty;
    final bool isCurrentPassFilled = currentPasswordCtrl.text.isNotEmpty;

    // Final check to enable Save button
    final bool isAllValid = hasMinLength && hasUppercase && hasLowercase && hasDigit && hasSpecialChar && passwordsMatch && isCurrentPassFilled;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFDDEEF8), Color(0xFFF2F9FE), Colors.white],
              stops: [0.0, 0.35, 0.6],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _buildHeader(context),

                Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // بوكس لغة الإشارة (نفس شكل صفحة التواصل)
                      const SignLanguageVideoBox(
                        videoAsset: 'assets/videos/sign_change_password.mp4',
                      ),
                      Focus(
                        onFocusChange: (hasFocus) {
                          if (!hasFocus) _validateCurrentPassword(currentPasswordCtrl.text);
                        },
                        child: _buildPasswordField('كلمة المرور الحالية', currentPasswordCtrl, obscureText: _obscureCurrent, onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent), onChanged: (val) {
                          if (_currentPasswordError.isNotEmpty) _validateCurrentPassword(val);
                          setState(() {});
                        }),
                      ),
                      _buildErrorText(_currentPasswordError),
                      const SizedBox(height: 20),

                      Focus(
                        onFocusChange: (hasFocus) {
                          setState(() => _newPasswordFocused = hasFocus);
                          if (!hasFocus) _validatePassword(newPasswordCtrl.text);
                        },
                        child: _buildPasswordField('كلمة المرور الجديدة', newPasswordCtrl, obscureText: _obscureNew, onToggle: () => setState(() => _obscureNew = !_obscureNew), onChanged: _onNewPasswordChanged),
                      ),

                      // 👇 شروط كلمة المرور (نفس صفحة إنشاء الحساب)
                      if (_newPasswordFocused || newPass.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10, right: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRequirement('8 خانات على الأقل', hasMinLength),
                              _buildRequirement('حرف كبير (A-Z)', hasUppercase),
                              _buildRequirement('حرف صغير (a-z)', hasLowercase),
                              _buildRequirement('رقم (0-9)', hasDigit),
                              _buildRequirement('رمز (!@#\$&*~%^)', hasSpecialChar),
                            ],
                          ),
                        ),
                      _buildErrorText(_passwordError),
                      const SizedBox(height: 20),

                      Focus(
                        onFocusChange: (hasFocus) {
                          setState(() {
                            _confirmPasswordFocused = hasFocus;
                            if (!hasFocus && repeatPasswordCtrl.text.isEmpty) {
                              _confirmPasswordStatus = 'empty';
                            }
                          });
                        },
                        child: _buildPasswordField('تأكيد كلمة المرور الجديدة', repeatPasswordCtrl, obscureText: _obscureRepeat, onToggle: () => setState(() => _obscureRepeat = !_obscureRepeat), onChanged: _onConfirmPasswordChanged),
                      ),

                      // 👇 حالة تطابق كلمة المرور (نفس صفحة إنشاء الحساب)
                      if (_confirmPasswordStatus == 'match' && _confirmPasswordFocused)
                        _buildStatusRow('كلمة المرور متطابقة', ok: true),
                      if (_confirmPasswordStatus == 'nomatch')
                        _buildStatusRow('كلمة المرور غير متطابقة', ok: false),
                      if (_confirmPasswordStatus == 'empty')
                        _buildStatusRow('تأكيد كلمة المرور مطلوب', ok: false),

                      const SizedBox(height: 60),

                      // Full Width Save Button (No Cancel)
                      Container(
                        height: 60,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: isAllValid
                              ? const LinearGradient(
                                  colors: [Color(0xFF181059), Color(0xFF1773CF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isAllValid ? null : NabeehColors.slate300,
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () async {
                            if (!isAllValid) {
                              _showAllErrors();
                              return;
                            }
                            setState(() => _isLoading = true);
                            try {
                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null && user.email != null) {
                                final credential = EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: currentPasswordCtrl.text,
                                );
                                await user.reauthenticateWithCredential(credential);
                                await user.updatePassword(newPasswordCtrl.text);

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم تغيير كلمة المرور بنجاح!', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            } on FirebaseAuthException catch (e) {
                              String message = 'حدث خطأ أثناء التغيير. الرجاء المحاولة لاحقاً.';
                              if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                                if (mounted) {
                                  setState(() => _currentPasswordError = 'كلمة المرور الحالية غير صحيحة');
                                }
                                return;
                              } else if (e.code == 'network-request-failed') {
                                message = 'تأكد من اتصالك بالإنترنت.';
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(message, style: const TextStyle(fontFamily: 'IBMPlexSansArabic')),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint('Error updating password: $e');
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent, 
                            shadowColor: Colors.transparent, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: EdgeInsets.zero,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isLoading)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              else
                                const Icon(LucideIcons.save, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'حفظ التغييرات',
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 64, bottom: 20, right: 20, left: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(
                      color: const Color(0xFF181059), 
                      width: 1.5,
                    ),
                  ),
                  child: const Directionality(
                    textDirection: TextDirection.ltr, 
                    child: Icon(
                      Icons.arrow_forward_ios_rounded, 
                      color: Color(0xFF181059), 
                      size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'تغيير كلمة المرور', // 👉 Header Title changed here
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181059),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),

          // زر لغة الإشارة (نفس صفحة التواصل)
          const SignLanguageToggleButton(),
        ],
      ),
    );
  }

  // ── نفس عناصر الخطأ في صفحة إنشاء الحساب ───────────────────────────────
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

  Widget _buildStatusRow(String text, {required bool ok}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: ok ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 12,
              color: ok ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, {
    required bool obscureText,
    required VoidCallback onToggle,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      style: const TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic', color: NabeehColors.slate500, fontSize: 14),
        filled: true,
        fillColor: NabeehColors.slate50,
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: NabeehColors.slate500,
            size: 22,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NabeehColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NabeehColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NabeehColors.lightBlue, width: 2),
        ),
      ),
    );
  }
}
