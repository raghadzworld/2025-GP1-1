import 'package:flutter/material.dart';
import 'nabeeh_colors.dart';

class EditProfileScreen extends StatelessWidget {
  final VoidCallback onBack;
  const EditProfileScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Top gradient background
            Container(
              height: 200,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFB8D4F0), Colors.white],
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      _buildHeader(), 
                      const SizedBox(height: 40),
                      _buildEditInput('الاسم', Icons.person_outline, 'ريم العويس'),
                      const SizedBox(height: 20),
                      _buildEditInput('الايميل', Icons.email_outlined, 'Reem@gmail.com'),
                      const SizedBox(height: 20),
                      _buildEditInput('رقم الهاتف', Icons.phone_android_outlined, '050 123 4567'),
                      const SizedBox(height: 60),
                      _buildSaveButton(),
                      const SizedBox(height: 15),
                      _buildDeleteButton(context), 
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Right Side: Back Arrow (Matching Login Screen style)
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: NabeehColors.dark, 
                width: 1.5,
              ),
            ),
            // 👇 Here is the fix: Forcing Left-to-Right direction so the icon points Right
            child: const Directionality(
              textDirection: TextDirection.ltr,
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: NabeehColors.dark, 
                size: 18, 
              ),
            ),
          ),
        ),

        // Center: Title
        const Text(
          'تعديل الملف',
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: NabeehColors.dark,
            letterSpacing: -1,
          ),
        ),

        // Left Side: Blue Icon (Matching Login Screen)
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF181059), Color(0xFF181059), Color(0xFF1773CF)],
              stops: [0.09, 0.30, 1.0],
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
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: onBack,
      icon: const Icon(Icons.save, color: Colors.white),
      label: const Text(
        'حفظ التغييرات',
        style: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 16, 
          fontWeight: FontWeight.bold, 
          color: Colors.white
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: NabeehColors.dark, 
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        _showDeleteConfirmation(context);
      },
      icon: const Icon(Icons.delete_outline, color: Color(0xFFFF3B30)),
      label: const Text(
        'حذف الحساب',
        style: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          fontSize: 16, 
          color: Color(0xFFFF3B30), 
          fontWeight: FontWeight.bold
        ),
      ),
      style: TextButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: const Color(0xFFFF3B30).withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'تأكيد الحذف', 
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic', 
                fontWeight: FontWeight.bold, 
                color: NabeehColors.darkBlue
              )
            ),
            content: const Text(
              'هل أنت متأكد من رغبتك في حذف حسابك نهائياً؟',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic', 
                fontSize: 15,
                color: NabeehColors.darkNavy
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                        ),
                      ),
                      child: const Text(
                        'إلغاء', 
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic', 
                          color: NabeehColors.gray, 
                          fontWeight: FontWeight.bold
                        )
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'تأكيد الحذف', 
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic', 
                          color: Colors.white, 
                          fontWeight: FontWeight.bold
                        )
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

  Widget _buildEditInput(String label, IconData icon, String initialValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontWeight: FontWeight.bold, 
            color: NabeehColors.darkBlue
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: initialValue),
          style: const TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 14,
            color: NabeehColors.darkNavy,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              borderSide: const BorderSide(color: NabeehColors.lightBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}