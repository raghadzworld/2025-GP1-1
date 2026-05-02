import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'nabeeh_colors.dart';
import 'welcome_screen.dart'; 

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController(); 
  
  bool _isLoading = false;

  // --- Inline error ribbon state ---
  String? _nameError;
  String? _emailSaveError;

  // --- Dynamic Email State Variables ---
  bool _emailChanged = false;
  bool _isSendingLink = false;
  bool _linkSent = false;
  String _lastSentEmail = '';
  String _originalEmail = ''; 

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
    
    _nameController.addListener(() { if (_nameError != null) setState(() => _nameError = null); });
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
            final loadedEmail = data['Email']?.isNotEmpty == true
                ? data['Email'] as String
                : (user.email ?? '');
            _emailController.text = loadedEmail;
            _originalEmail = loadedEmail; 
          });
          _emailController.addListener(_onEmailTextChanged);
        }
      } catch (e) {
        debugPrint("Error loading user data: $e");
      }
    }
  }

  void _onEmailTextChanged() {
    final currentInput = _emailController.text.trim();
    final hasChanged = currentInput != _originalEmail && currentInput.isNotEmpty;

    if (_emailChanged != hasChanged) {
      setState(() => _emailChanged = hasChanged);
    }

    if (_linkSent && currentInput != _lastSentEmail) {
      setState(() {
        _linkSent = false;
        _emailSaveError = null;
      });
    }
    if (_emailSaveError != null && !_linkSent) {
      setState(() => _emailSaveError = null);
    }
  }

  // --- Send the verification link (Mirrors SignupScreen error handling) ---
  Future<void> _sendVerificationLink() async {
    setState(() {
      _isSendingLink = true;
      _emailSaveError = null; 
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      final newEmail = _emailController.text.trim();
      
      if (user != null) {
        // SAVE NAME FIRST
        try {
          await FirebaseFirestore.instance.collection('User').doc(user.uid).set({
            'FullName': _nameController.text.trim(),
          }, SetOptions(merge: true));
        } catch (_) {}

        // SEND THE LINK
        await user.verifyBeforeUpdateEmail(newEmail);
        
        setState(() {
          _linkSent = true;
          _lastSentEmail = newEmail;
        });
      }
    } on FirebaseAuthException catch (e) {
      // Logic extracted from SignupScreen
      String message = 'حدث خطأ، حاولي مرة أخرى';
      if (e.code == 'email-already-in-use') message = 'البريد مستخدم مسبقاً';
      if (e.code == 'invalid-email') message = 'البريد الإلكتروني غير صحيح';
      if (e.code == 'requires-recent-login' || (e.message?.contains('valid') ?? false)) {
        message = 'لأسباب أمنية، يرجى تسجيل الخروج والدخول مجدداً لتغيير الإيميل.';
      }

      if (mounted) {
        setState(() {
          _emailSaveError = message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailSaveError = 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSendingLink = false);
    }
  }

  // --- Final Save ---
  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = 'الاسم الكامل مطلوب';
        _emailSaveError = null;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        
        if (_emailChanged) {
          final uid = user.uid;
          final newEmail = _emailController.text.trim();

          await FirebaseFirestore.instance.collection('User').doc(uid).set({
            'FullName': name,
            'Email': newEmail,
          }, SetOptions(merge: true));

          bool emailConfirmed = false;
          try {
            await user.reload();
            final updatedUser = FirebaseAuth.instance.currentUser;
            if (updatedUser != null && updatedUser.email == newEmail) {
              emailConfirmed = true;
            }
          } on FirebaseAuthException {
            emailConfirmed = true;
          } catch (_) {
            emailConfirmed = true;
          }

          if (!emailConfirmed) {
            if (mounted) {
              setState(() {
                _emailSaveError = 'لم يتم تأكيد البريد بعد. يرجى الضغط على الرابط في بريدك أولاً.';
                _isLoading = false;
              });
            }
            return;
          }

          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'تم تحديث البريد الإلكتروني بنجاح! يرجى تسجيل الدخول مجدداً.',
                  style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              (Route<dynamic> route) => false,
            );
          }
          return;
        }

        // --- NORMAL SAVE (Name Only) ---
        await FirebaseFirestore.instance.collection('User').doc(user.uid).set({
          'FullName': name,
        }, SetOptions(merge: true));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث الملف الشخصي بنجاح', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); 
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(fontFamily: 'IBMPlexSansArabic')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailTextChanged);
    _nameController.dispose();
    _emailController.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isPendingEmail = _emailChanged && !_linkSent;
    bool isSaveDisabled = _isLoading || isPendingEmail;

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
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      const SizedBox(height: 20),
                      
                      _buildTextField(
                        controller: _nameController,
                        label: 'الاسم الكامل',
                        icon: LucideIcons.user,
                      ),
                      if (_nameError != null) _buildErrorRibbon(_nameError!),
                      const SizedBox(height: 20),

                      _buildTextField(
                        controller: _emailController,
                        label: 'الايميل',
                        icon: LucideIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      
                      // --- DYNAMIC EMAIL STATUS UI ---
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: (_emailChanged || _linkSent) ? 45 : 0, 
                        margin: EdgeInsets.only(top: (_emailChanged || _linkSent) ? 8 : 0),
                        child: _linkSent 
                          ? const Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'تم إرسال الرابط. يرجى التأكيد في بريدك ثم الضغط على حفظ بالأسفل.', 
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic', 
                                  color: Color(0xFF1773CF), 
                                  fontSize: 13, 
                                  fontWeight: FontWeight.w600
                                ),
                              ),
                            )
                          : (_emailChanged ? Align(
                              alignment: Alignment.centerRight, 
                              child: OutlinedButton(
                                onPressed: _isSendingLink ? null : _sendVerificationLink,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFF181059), width: 1.5),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: _isSendingLink
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Color(0xFF181059), strokeWidth: 2))
                                  : const Text(
                                      'إرسال رابط التأكيد', 
                                      style: TextStyle(fontFamily: 'IBMPlexSansArabic', color: Color(0xFF181059), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                              ),
                            ) : const SizedBox.shrink()),
                      ),
                      if (_emailSaveError != null) _buildErrorRibbon(_emailSaveError!),
                      
                      const SizedBox(height: 60),

                      // --- MAIN SAVE BUTTON ---
                      Container(
                        height: 60, 
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: isSaveDisabled 
                            ? const LinearGradient(colors: [Color(0xFFD1D5DB), Color(0xFF9CA3AF)])
                            : const LinearGradient(
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
                          onPressed: isSaveDisabled ? null : _saveProfile,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.save, color: isSaveDisabled ? Colors.white70 : Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'حفظ التغييرات',
                                      style: TextStyle(
                                        fontFamily: 'IBMPlexSansArabic',
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isSaveDisabled ? Colors.white70 : Colors.white,
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

  Widget _buildErrorRibbon(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF4D4D), width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                color: Color(0xFFD32F2F),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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