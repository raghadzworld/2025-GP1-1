import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'listening_screen.dart';
import 'reminders_screen.dart';
import 'stt_tts_screen.dart';

// ─── Colors ───────────────────────────────────────────────────────────────────
class NabeehColors {
  static const darkNavy  = Color(0xFF181059);
  static const darkBlue  = Color(0xFF21277B);
  static const lightBlue = Color(0xFF1773CF);
  static const yellow    = Color(0xFFFFD350);
  static const green     = Color(0xFF00AA5B);
  static const gray      = Color(0xFFA4ACB0);
  static const background = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFA4ACB0);
}

const _kBlueGradient = LinearGradient(
  colors: [Color(0xFF181059), Color(0xFF181059), Color(0xFF1773CF)],
  stops: [0.09, 0.30, 1.0],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

class HomeScreen extends StatefulWidget {
  // إضافة هذا السطر لاستقبال وظيفة التنقل من الصفحة الرئيسية
  final VoidCallback? onMoreInfoPressed;

  const HomeScreen({super.key, this.onMoreInfoPressed});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // محاولة أولى: جلب بالـ UID مباشرة
      final doc = await FirebaseFirestore.instance
          .collection('User')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() => _userName = doc.data()?['FullName'] ?? '');
        return;
      }

      // محاولة ثانية: البحث بالإيميل
      final query = await FirebaseFirestore.instance
          .collection('User')
          .where('Email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty && mounted) {
        setState(() => _userName = query.docs.first.data()['FullName'] ?? '');
      }
    } catch (_) {
      // الاسم يبقى فارغاً إذا فشل الجلب
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFDDEEF8), Color(0xFFF2F9FE), Colors.white],
            stops: [0.0, 0.35, 0.6],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  _buildWatchCard(),
                  const SizedBox(height: 14),
                  _buildFeaturesSection(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 64, bottom: 20, right: 20, left: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'أهــــلًا${_userName.isNotEmpty ? ' $_userName' : ''}',
            style: const TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF181059),
            ),
          ),
          Container(
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
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
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

  Widget _buildWatchCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NabeehColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'معلومات الساعة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: NabeehColors.darkBlue,
                ),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF1F1F1), Color(0xFFF3F3F3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF9F9F9F)),
                ),
                child: const Icon(
                  Icons.watch_rounded,
                  color: NabeehColors.darkBlue,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'حالة الساعة:',
              style: TextStyle(fontSize: 17, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'غير متصلة',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: widget.onMoreInfoPressed,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF181059), Color(0xFF1773CF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(
                child: Text(
                  'للمزيد من المعلومات',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text(
              'كيف يمكنني مساعدتك ؟',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: NabeehColors.darkBlue,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _buildGridCard(
              title: 'المجموعات\nالصوتية',
              icon: 'assets/images/icon_Ycato.png',
              onTap: () => Navigator.pushNamed(context, '/categories'),
            ),
            _buildGridCard(
              title: 'الاستشعار\nالصوتي',
              icon: 'assets/images/icon_YReco.png',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListeningScreen())),
            ),
            _buildGridCard(
              title: 'التواصل',
              icon: 'assets/images/icon_YCom.png',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SttTtsScreen())),
            ),
            _buildGridCard(
              title: 'المنبّه',
              icon: 'assets/images/icon_YRima.png',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersScreen())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridCard({
    required String title,
    required String icon,
    required VoidCallback onTap,
    Color titleColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: _kBlueGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 16,
              right: 16,
              child: Image.asset(icon, width: 38, height: 38, fit: BoxFit.contain),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
