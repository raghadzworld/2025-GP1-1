import 'package:flutter/material.dart';
import 'nabeeh_colors.dart';

class ProfileInfoScreen extends StatelessWidget {
  final VoidCallback onEdit;
  const ProfileInfoScreen({super.key, required this.onEdit});

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
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  _buildHeader(context),
                  const SizedBox(height: 40),
                  _buildInfoRow(Icons.email, 'الايميل', 'Reem@gmail.com'),
                  _buildInfoRow(Icons.phone_android, 'رقم الهاتف', '050 123 4567'),
                  const Spacer(),
                  _buildCommandButtons(context),
                  const SizedBox(height: 40), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Right Side: Name (Aligned to the side as requested)
          const Text(
            'ريم العويس',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 32, // Increased size slightly to match the side-alignment aesthetic
              fontWeight: FontWeight.bold,
              color: NabeehColors.darkBlue,
            ),
          ),

          // Left Side: Blue Icon
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

  Widget _buildCommandButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, color: Colors.white),
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
              Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
            },
            icon: const Icon(Icons.logout, color: NabeehColors.dark), 
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
              minimumSize: const Size(double.infinity, 60),
              side: const BorderSide(color: NabeehColors.dark, width: 1.5), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: NabeehColors.darkBlue,
                ),
              ),
            ],
          ),
          const Divider(height: 30, thickness: 0.5),
        ],
      ),
    );
  }
}