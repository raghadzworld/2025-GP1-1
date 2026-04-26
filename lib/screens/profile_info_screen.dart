import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nabeeh_colors.dart';
import 'settings_screen.dart';

class ProfileInfoScreen extends StatelessWidget {
  final VoidCallback onEdit;
  const ProfileInfoScreen({super.key, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    // Get the current logged-in user's ID
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Container(
              height: 250,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFB8D4F0), Colors.white],
                ),
              ),
            ),
            SafeArea(
              child: currentUser == null 
                ? const Center(child: Text('الرجاء تسجيل الدخول أولاً', style: TextStyle(fontFamily: 'IBMPlexSansArabic')))
                : StreamBuilder<DocumentSnapshot>(
                    // Listen to this user's specific document in Firestore
                    stream: FirebaseFirestore.instance.collection('User').doc(currentUser.uid).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: NabeehColors.darkBlue));
                      }

                      // Extract data with safe fallbacks
                      final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                      final String name = userData['FullName'] ?? 'مستخدم جديد';
                      final String email = currentUser.email ?? userData['Email'] ?? 'لا يوجد بريد إلكتروني';
                      final String phone = userData['PhoneNumber'] ?? 'لم يتم إضافة رقم';

                      return Column(
                        children: [
                          const SizedBox(height: 30),
                          _buildHeader(context, name),
                          const SizedBox(height: 40),
                          
                          _buildInfoRow(Icons.email, 'الايميل', email),
                          _buildInfoRow(Icons.phone_android, 'رقم الهاتف', phone),
                          
                          const Spacer(),
                          _buildCommandButtons(context),
                          const SizedBox(height: 40), 
                        ],
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: NabeehColors.darkBlue,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label, 
            style: const TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              color: Colors.grey, 
              fontSize: 14
            )
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1773CF), size: 22),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: NabeehColors.darkBlue,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 30, thickness: 0.5),
        ],
      ),
    );
  }

  Widget _buildCommandButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: onEdit,
            icon: const Icon(LucideIcons.edit2, color: Colors.white, size: 20),
            label: const Text(
              'تعديل الملف الشخصي',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: Colors.white
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: NabeehColors.dark,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const SettingsScreen())
              );
            },
            icon: const Icon(LucideIcons.settings, color: NabeehColors.dark, size: 20), 
            label: const Text(
              'الإعدادات',
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
        ],
      ),
    );
  }
}