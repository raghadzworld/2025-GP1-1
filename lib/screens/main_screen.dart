import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'emergency_screen.dart';
import 'watch_screen.dart';   

// 👇 استيراد شاشات الملف الشخصي هنا
import 'profile_info_screen.dart';
import 'edit_profile_screen.dart';

// ─── Nav Item Model ───────────────────────────────────────────────────────────
class _NavItem {
  final String label;
  final String selectedIcon;
  final String unselectedIcon;
  const _NavItem({
    required this.label, 
    required this.selectedIcon, 
    required this.unselectedIcon
  });
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; 

  // تحديث المسارات بناءً على الصور الجديدة في الـ Assets
  final List<_NavItem> _navItems = const [
    _NavItem(
      label: 'المنزل',
      selectedIcon: 'assets/images/icon_SlectedHome.png',
      unselectedIcon: 'assets/images/icon_NotSHome.png',
    ),
    _NavItem(
      label: 'الساعة',
      selectedIcon: 'assets/images/icon_SlectedWatch.png',
      unselectedIcon: 'assets/images/icon_NotSWatch.png',
    ),
    _NavItem(
      label: 'طوارئ',
      selectedIcon: 'assets/images/icon_SlectedEme.png',
      unselectedIcon: 'assets/images/icon_NotSEme.png',
    ),
    _NavItem(
      label: 'حسابي',
      selectedIcon: 'assets/images/icon_SlectedProfile.png',
      unselectedIcon: 'assets/images/icon_NotSProfile.png',
    ),
  ];

  Widget _buildPage(int index) {
    switch (index) {
      case 0: 
        return HomeScreen(
          onMoreInfoPressed: () {
            setState(() {
              _currentIndex = 1; 
            });
          },
        );
      case 1: return const WatchScreen();
      case 2: return const EmergencyScreen();
      
      // 👇 تم ربط شاشة الملف الشخصي هنا
      case 3: 
        return ProfileInfoScreen(
          onEdit: () {
            // الانتقال إلى شاشة تعديل الملف عند الضغط على الزر
            Navigator.push(
              context,
              MaterialPageRoute(
                // 👇 Removed the onBack error here!
                builder: (context) => const EditProfileScreen(),
              ),
            );
          },
        );
      
      default: return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(4, (i) => _buildPage(i)),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
          child: _buildNavBar(),
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_navItems.length, (index) {
          final isSelected = index == _currentIndex;
          final item = _navItems[index];

          return GestureDetector(
            onTap: () => setState(() => _currentIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE8F1FB) : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    isSelected ? item.selectedIcon : item.unselectedIcon,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      index == 0 ? Icons.home : index == 1 ? Icons.watch_later : index == 2 ? Icons.notifications_active : Icons.person,
                      color: isSelected ? const Color(0xFF1773CF) : Colors.grey,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontFamily: 'IBMPlexSansArabic', 
                        color: Color(0xFF1773CF),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}