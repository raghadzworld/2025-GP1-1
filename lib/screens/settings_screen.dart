import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nabeeh_colors.dart';
import '../features/categories/data/services/category_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // 👇 1. Firebase Logout Logic
  Future<void> _logout(BuildContext context) async {
    try {
      // تسجيل الخروج من فايربيس
      await FirebaseAuth.instance.signOut();
      
      // مسح البيانات المحلية إذا لزم الأمر
      await CategoryService.withDefaults().logout(); 

      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تسجيل الخروج: $e', style: const TextStyle(fontFamily: 'IBMPlexSansArabic')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// 👇 2. Firebase Delete Account Logic
  Future<void> _deleteAccount(BuildContext context) async {
    // إظهار مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => const Center(child: CircularProgressIndicator(color: Colors.red)),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final uid = user.uid;
        
        // 1. حذف بيانات المستخدم من Firestore
        await FirebaseFirestore.instance.collection('User').doc(uid).delete();
        
        // 2. حذف الحساب من Firebase Auth
        await user.delete();

        if (context.mounted) {
          // إغلاق مؤشر التحميل بشكل آمن
          Navigator.of(context, rootNavigator: true).pop(); 
          
          // إظهار رسالة التأكيد
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الحساب بنجاح. نتمنى رؤيتك قريباً!', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );

          // الانتقال إلى صفحة الترحيب
          Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
        }
      } else {
        // في حال كان المستخدم غير موجود، نغلق التحميل فقط
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop(); // إغلاق مؤشر التحميل

      if (e.code == 'requires-recent-login') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لأسباب أمنية، يرجى تسجيل الخروج ثم الدخول مجدداً قبل محاولة حذف الحساب.', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ: ${e.message}', style: const TextStyle(fontFamily: 'IBMPlexSansArabic')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      debugPrint('Error deleting account: $e');
    }
  }

  // 👇 3. LIVE Validation Change Password Dialog
  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final repeatPasswordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder allows the dialog to update live as the user types
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            // Extract current text
            final newPass = newPasswordCtrl.text;
            final repeatPass = repeatPasswordCtrl.text;

            // Live Validation Rules
            final bool hasMinLength = newPass.length >= 8;
            final bool hasUppercase = RegExp(r'[A-Z]').hasMatch(newPass);
            final bool hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(newPass);
            final bool passwordsMatch = newPass == repeatPass && repeatPass.isNotEmpty;
            final bool isCurrentPassFilled = currentPasswordCtrl.text.isNotEmpty;

            // Final check to enable Save button
            final bool isAllValid = hasMinLength && hasUppercase && hasSpecialChar && passwordsMatch && isCurrentPassFilled;

            // Triggered every time a character is typed
            void onTextChanged(String _) {
              setDialogState(() {});
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text(
                  'تغيير كلمة المرور',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontWeight: FontWeight.bold,
                    color: NabeehColors.darkBlue,
                    fontSize: 20,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPasswordField('كلمة المرور الحالية', currentPasswordCtrl, onChanged: onTextChanged),
                      const SizedBox(height: 16),
                      
                      _buildPasswordField('كلمة المرور الجديدة', newPasswordCtrl, onChanged: onTextChanged),
                      const SizedBox(height: 12),
                      
                      // 👇 Live Rule Indicators
                      _buildValidationRow('8 أحرف أو أكثر', hasMinLength),
                      _buildValidationRow('حرف إنجليزي كبير واحد على الأقل', hasUppercase),
                      _buildValidationRow('رمز خاص واحد على الأقل (!@#...)', hasSpecialChar),
                      
                      const SizedBox(height: 16),
                      _buildPasswordField('تأكيد كلمة المرور الجديدة', repeatPasswordCtrl, onChanged: onTextChanged),
                      const SizedBox(height: 12),
                      
                      // 👇 Password Match Indicator
                      _buildValidationRow('تطابق كلمة المرور', passwordsMatch),
                    ],
                  ),
                ),
                actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                actions: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            fixedSize: const Size.fromHeight(50), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              color: NabeehColors.slate500,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          // Disable button if rules aren't met
                          onPressed: isAllValid ? () async {
                            try {
                              // 1. إظهار مؤشر التحميل (Loading Indicator)
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(child: CircularProgressIndicator(color: NabeehColors.lightBlue)),
                              );

                              final user = FirebaseAuth.instance.currentUser;
                              if (user != null && user.email != null) {
                                
                                // 2. إعادة المصادقة باستخدام كلمة المرور الحالية (مطلوب من فايربيس للأمان)
                                final credential = EmailAuthProvider.credential(
                                  email: user.email!,
                                  password: currentPasswordCtrl.text,
                                );
                                await user.reauthenticateWithCredential(credential);

                                // 3. تحديث كلمة المرور
                                await user.updatePassword(newPasswordCtrl.text);

                                // 4. إغلاق مؤشر التحميل ونافذة التغيير
                                if (context.mounted) {
                                  Navigator.pop(context); // إغلاق التحميل
                                  Navigator.pop(context); // إغلاق النافذة
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم تغيير كلمة المرور بنجاح!', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            } on FirebaseAuthException catch (e) {
                              if (context.mounted) Navigator.pop(context); // إغلاق التحميل في حال الخطأ
                              
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
                            fixedSize: const Size.fromHeight(50), 
                            // Change color based on validity
                            backgroundColor: isAllValid ? NabeehColors.lightBlue : NabeehColors.slate300,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'حفظ',
                            style: TextStyle(
                              fontFamily: 'IBMPlexSansArabic', 
                              fontWeight: FontWeight.bold, 
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  // Visual row for validation checks
  Widget _buildValidationRow(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isValid ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
            color: isValid ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isValid ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  // Added onChanged parameter
  Widget _buildPasswordField(String label, TextEditingController controller, {Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      obscureText: true,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic', color: NabeehColors.slate500, fontSize: 14),
        filled: true,
        fillColor: NabeehColors.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NabeehColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NabeehColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NabeehColors.lightBlue, width: 2),
        ),
      ),
    );
  }

void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // 👈 Changed to dialogContext
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(LucideIcons.alertTriangle, color: Colors.red),
                SizedBox(width: 10),
                Text(
                  'حذف الحساب',
                  style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
            content: const Text(
              'هل أنت متأكد من رغبتك في حذف حسابك نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 16),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext), // 👈 Use dialogContext here
                      style: TextButton.styleFrom(
                        fixedSize: const Size.fromHeight(50), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic', 
                          color: NabeehColors.slate500, 
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext); // 👈 Close the dialog first
                        await _deleteAccount(context); // 👈 Pass the MAIN screen context!
                      },
                      style: ElevatedButton.styleFrom(
                        fixedSize: const Size.fromHeight(50), 
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'حذف نهائي',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic', 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
                  _buildHeader(context),
                  const SizedBox(height: 40),
                  
                  _buildSettingsTile(
                    icon: LucideIcons.lock,
                    title: 'تغيير كلمة المرور',
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                  _buildSettingsTile(
                    icon: LucideIcons.trash2,
                    title: 'حذف الحساب',
                    titleColor: Colors.red,
                    iconColor: Colors.red,
                    onTap: () => _confirmDeleteAccount(context),
                  ),
                  
                  const Spacer(),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: OutlinedButton.icon(
                      onPressed: () => _logout(context),
                      icon: const Icon(LucideIcons.logOut, color: NabeehColors.dark, size: 20), 
                      label: const Text(
                        'تسجيل الخروج',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: NabeehColors.dark 
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 60),
                        side: const BorderSide(color: NabeehColors.dark, width: 1.5), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 24, right: 24, left: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB8D4F0), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              'الإعدادات',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF181059),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
              child: const Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon, 
    required String title, 
    required VoidCallback onTap, 
    Color titleColor = NabeehColors.darkBlue, 
    Color iconColor = NabeehColors.darkBlue
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: NabeehColors.slate50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NabeehColors.slate200, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const Spacer(),
              const Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: NabeehColors.slate400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}