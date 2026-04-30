import 'package:flutter/material.dart';
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
          });
        }
      } catch (e) {
        debugPrint("Error loading user data: $e");
      }
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('User').doc(user.uid).set({
          'FullName': _nameController.text.trim(),
          'PhoneNumber': _phoneController.text.trim(),
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
          const SnackBar(
            content: Text('حدث خطأ أثناء التحديث', style: TextStyle(fontFamily: 'IBMPlexSansArabic')),
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
                          const SizedBox(height: 20), // Replaced Avatar with just spacing
                          
                          _buildTextField(
                            controller: _nameController,
                            label: 'الاسم الكامل',
                            icon: LucideIcons.user,
                          ),
                          const SizedBox(height: 20),
                          
                          _buildTextField(
                            controller: _phoneController,
                            label: 'رقم الهاتف',
                            icon: LucideIcons.phone,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 60),

                          ElevatedButton(
                            onPressed: _isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF181059),
                              minimumSize: const Size(double.infinity, 60),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'حفظ التغييرات',
                                    style: TextStyle(
                                      fontFamily: 'IBMPlexSansArabic', 
                                      fontSize: 18, 
                                      fontWeight: FontWeight.bold, 
                                      color: Colors.white
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
          const Expanded(
            child: Text(
              'تعديل الملف',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontFamily: 'IBMPlexSansArabic', 
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: NabeehColors.darkBlue,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'IBMPlexSansArabic', color: NabeehColors.slate500, fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, color: Color(0xFF181059), size: 22),
        filled: true,
        fillColor: NabeehColors.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NabeehColors.slate200, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NabeehColors.slate200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NabeehColors.lightBlue, width: 2),
        ),
      ),
    );
  }
}