import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileInfoScreen extends StatelessWidget {
  final VoidCallback onEdit;
  const ProfileInfoScreen({super.key, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Top gradient background
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade100, Colors.white],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                _buildHeader(), // Reem Al-Owais (Left) + Profile Image (Right)
                const SizedBox(height: 50),
                _buildInfoRow(Icons.email, 'الايميل', 'Reem@gmile.com'),
                _buildInfoRow(Icons.phone, 'رقم الهاتف', '050 123 4567'),
                const Spacer(),
                _buildCommandButtons(),
                const SizedBox(height: 100),
              ],
            ),
          ),
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'ريم العويس',
          style: GoogleFonts.notoSansArabic(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A40),
          ),
        ),
      ),
    );
  }

  Widget _buildCommandButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text(
              'تعديل الملف الشخصي',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.logout, color: Colors.grey),
            label: const Text(
              'تسجيل الخروج',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 60),
              side: BorderSide(color: Colors.grey.shade200),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: Container(
        height: 75,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(37.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            // 4. Home Icon
            IconButton(
              onPressed: () {},
              icon: Image.asset('assets/images/home.png', width: 24, height: 24),
            ),
            const Spacer(),
            
            // 3. Watch/Bracelet Icon
            IconButton(
              onPressed: () {},
              icon: Image.asset('assets/images/bracelet.png', width: 24, height: 24),
            ),
            const Spacer(),
            
            // 2. SOS Icon
            IconButton(
              onPressed: () {},
              icon: Image.asset('assets/images/sos.png', width: 24, height: 24),
            ),
            const Spacer(),
            
            // 1. Profile Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Row(
                children: [
                  Icon(Icons.person, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'الملف الشخصي',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: Colors.blue, size: 22),
              const SizedBox(width: 15),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A40),
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