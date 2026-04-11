import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'emergency_screen.dart';

// ─── Placeholder screens ──────────────────────────────────────────────────────
class WatchScreen extends StatelessWidget {
  const WatchScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Text('صفحة الساعة', style: TextStyle(fontSize: 20)));
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Text('صفحة الملف', style: TextStyle(fontSize: 20)));
}

// ─── Nav Item Model ───────────────────────────────────────────────────────────
class _NavItem {
  final String label;
  final String selectedIcon;
  final String unselectedIcon;
  const _NavItem({required this.label, required this.selectedIcon, required this.unselectedIcon});
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 3; // Home

  final List<_NavItem> _navItems = const [
    _NavItem(
      label: 'الملف',
      selectedIcon: 'assets/images/icon_SlectedProfile.png',
      unselectedIcon: 'assets/images/icon_NotSProfile.png',
    ),
    _NavItem(
      label: 'طوارئ',
      selectedIcon: 'assets/images/icon_SlectedEme.png',
      unselectedIcon: 'assets/images/icon_NotSEme.png',
    ),
    _NavItem(
      label: 'الساعة',
      selectedIcon: 'assets/images/icon_SlectedWatch.png',
      unselectedIcon: 'assets/images/icon_NotSWatch.png',
    ),
    _NavItem(
      label: 'المنزل',
      selectedIcon: 'assets/images/icon_SlectedHome.png',
      unselectedIcon: 'assets/images/icon_NotSHome.png',
    ),
  ];

  // Map index to page widget
  Widget _buildPage(int index) {
    switch (index) {
      case 0: return const ProfileScreen();
      case 1: return const EmergencyScreen();
      case 2: return const WatchScreen();
      case 3: return const HomeScreen();
      default: return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        // ── Pages ──
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(4, (i) => _buildPage(i)),
        ),
        // ── Nav Bar ──
        bottomNavigationBar: _buildNavBar(),
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_navItems.length, (index) {
          final isSelected = index == _currentIndex;
          final item = _navItems[index];

          return GestureDetector(
            onTap: () => setState(() => _currentIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: Color(0xFF1773CF),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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