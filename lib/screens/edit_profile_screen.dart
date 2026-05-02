import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'nabeeh_colors.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController(); 
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('User').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          setState(() {
            _nameController.text = data['FullName'] ?? '';
            _phoneController.text = data['PhoneNumber'] ?? '';
            _emailController.text = data['Email'] ?? user.email ?? ''; 
          });
        }
      } catch (e) {
        debugPrint("Error loading user data: $e");
      }
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    // --- 1. PHONE NUMBER VALIDATION ---
    final phone = _phoneController.text.trim();
    if (!phone.startsWith('05') || phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رقم الهاتف يجب أن يبدأ بـ 05 ويتكون من 10 أرقام', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
          backgroundColor: Colors.red,
        ),
      );
      return; 
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final newEmail = _emailController.text.trim();
        bool emailChanged = false; 

        // --- 2. EMAIL UPDATE ---
        if (user.email != newEmail && newEmail.isNotEmpty) {
          try {
            await user.verifyBeforeUpdateEmail(newEmail);
            emailChanged = true; 
          } on FirebaseAuthException catch (e) {
            if (e.code == 'requires-recent-login') {
              throw 'لأسباب أمنية، يرجى تسجيل الخروج والدخول مجدداً لتغيير البريد الإلكتروني.';
            } else if (e.code == 'email-already-in-use') {
              throw 'البريد الإلكتروني مستخدم بالفعل لحساب آخر.';
            } else {
              throw 'فشل تحديث البريد الإلكتروني: ${e.message}';
            }
          }
        }

        // --- 3. FIRESTORE UPDATE ---
        await FirebaseFirestore.instance.collection('User').doc(user.uid).set({
          'FullName': _nameController.text.trim(),
          'PhoneNumber': phone,
          'Email': newEmail,
        }, SetOptions(merge: true));
        
        if (mounted) {
          // --- 4. DYNAMIC SUCCESS MESSAGE ---
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                emailChanged 
                  ? 'تم الحفظ. يرجى مراجعة بريدك الجديد لتأكيد التغيير قبل تسجيل الدخول به.' 
                  : 'تم تحديث الملف الشخصي بنجاح', 
                style: const TextStyle(fontFamily: 'IBMPlexSansArabic')
              ),
              backgroundColor: Colors.green,
              duration: emailChanged ? const Duration(seconds: 6) : const Duration(seconds: 3),
            ),
          );
          Navigator.pop(context); 
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString(), style: const TextStyle(fontFamily: 'IBMPlexSansArabic')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose(); 
    super.dispose();
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
              const SizedBox(height: 30),
                  
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      _buildTextField(
                        controller: _nameController,
                        label: 'الاسم الكامل',
                        icon: LucideIcons.user,
                      ),
                      const SizedBox(height: 20),

                      _buildTextField(
                        controller: _emailController,
                        label: 'الايميل',
                        icon: LucideIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      
                      // --- PHONE FIELD WITH FORMATTERS ---
                      _buildTextField(
                        controller: _phoneController,
                        label: 'رقم الهاتف',
                        icon: LucideIcons.phone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly, 
                          LengthLimitingTextInputFormatter(10),   
                        ],
                      ),
                      const SizedBox(height: 60),

                      Container(
                        height: 60, 
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
                          onPressed: _isLoading ? null : _saveProfile,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.save, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'حفظ التغييرات',
                                      style: TextStyle(
                                        fontFamily: 'IBMPlexSansArabic',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 40), 
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 52, bottom: 20, right: 20, left: 20),
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
                    child: Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF181059), size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'تعديل الملف',
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
            onTap: () {
               // Add your gesture button action here
            },
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

  // --- UPDATED TEXT FIELD METHOD ---
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters, 
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters, 
      style: const TextStyle(
        fontFamily: 'IBMPlexSansArabic', 
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: NabeehColors.darkBlue,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic', color: NabeehColors.slate500, fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, color: const Color(0xFF181059), size: 22),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color.fromARGB(255, 235, 233, 229)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color.fromARGB(255, 235, 233, 229)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color.fromARGB(255, 235, 233, 229)),
        ),
      ),
    );
  }
}
