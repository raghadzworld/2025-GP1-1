import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'nabeeh_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final currentPasswordCtrl = TextEditingController();
  final newPasswordCtrl = TextEditingController();
  final repeatPasswordCtrl = TextEditingController();

  @override
  void dispose() {
    currentPasswordCtrl.dispose();
    newPasswordCtrl.dispose();
    repeatPasswordCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged(String _) {
    setState(() {}); // Re-trigger build for validation UI updates
  }

  @override
  Widget build(BuildContext context) {
    // Live Validation Rules
    final newPass = newPasswordCtrl.text;
    final repeatPass = repeatPasswordCtrl.text;

    final bool hasMinLength = newPass.length >= 8;
    final bool hasUppercase = RegExp(r'[A-Z]').hasMatch(newPass);
    final bool hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(newPass);
    final bool passwordsMatch = newPass == repeatPass && repeatPass.isNotEmpty;
    final bool isCurrentPassFilled = currentPasswordCtrl.text.isNotEmpty;

    // Final check to enable Save button
    final bool isAllValid = hasMinLength && hasUppercase && hasSpecialChar && passwordsMatch && isCurrentPassFilled;

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
                      _buildPasswordField('كلمة المرور الحالية', currentPasswordCtrl, onChanged: _onTextChanged),
                      const SizedBox(height: 20),
                      
                      _buildPasswordField('كلمة المرور الجديدة', newPasswordCtrl, onChanged: _onTextChanged),
                      const SizedBox(height: 16),
                      
                      // 👇 Live Rule Indicators
                      _buildValidationRow('8 أحرف أو أكثر', hasMinLength),
                      _buildValidationRow('حرف إنجليزي كبير واحد على الأقل', hasUppercase),
                      _buildValidationRow('رمز خاص واحد على الأقل (!@#...)', hasSpecialChar),
                      
                      const SizedBox(height: 20),
                      _buildPasswordField('تأكيد كلمة المرور الجديدة', repeatPasswordCtrl, onChanged: _onTextChanged),
                      const SizedBox(height: 16),
                      
                      // 👇 Password Match Indicator
                      _buildValidationRow('تطابق كلمة المرور', passwordsMatch),
                      
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
                          onPressed: isAllValid ? () async {
                            try {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(child: CircularProgressIndicator(color: NabeehColors.lightBlue)),
                              );

                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null && user.email != null) {
                                final credential = EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: currentPasswordCtrl.text,
                                );
                                await user.reauthenticateWithCredential(credential);
                                await user.updatePassword(newPasswordCtrl.text);

                                if (context.mounted) {
                                  Navigator.pop(context); // Close loading indicator
                                  Navigator.pop(context); // Go back to profile info screen
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم تغيير كلمة المرور بنجاح!', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            } on FirebaseAuthException catch (e) {
                              if (context.mounted) Navigator.pop(context); // Close loading indicator on error
                              
                              String message = 'حدث خطأ أثناء التغيير. الرجاء المحاولة لاحقاً.';
                              if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                                message = 'كلمة المرور الحالية غير صحيحة.';
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
                              if (context.mounted) Navigator.pop(context);
                              debugPrint('Error updating password: $e');
                            }
                          } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent, 
                            shadowColor: Colors.transparent, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.save, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
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

          GestureDetector(
            onTap: () {},
            child: Container(
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Image.asset(
                  'assets/images/icon_signLan.png',
                  color: NabeehColors.background,
                  colorBlendMode: BlendMode.srcIn,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationRow(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isValid ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
            color: isValid ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isValid ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, {Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      obscureText: true,
      onChanged: onChanged,
      style: const TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic', color: NabeehColors.slate500, fontSize: 14),
        filled: true,
        fillColor: NabeehColors.slate50,
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
