import 'package:flutter/material.dart';
import 'listening_screen.dart'; 
import 'reminders_screen.dart'; 
import 'stt_tts_screen.dart'; // 👇 Added import for the Communication screen

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
  int _selectedFeature = 0;

  final List<Map<String, String>> _features = [
    {
      'title': 'المجموعات\nالصوتية',
      'iconSelected':   'assets/images/icon_Ycato.png',
      'iconUnselected': 'assets/images/icon_GCato.png',
      'route': '/categories',          
    },
    {
      'title': 'تسجيل\nالصوت',
      'iconSelected':   'assets/images/icon_YReco.png',
      'iconUnselected': 'assets/images/icon_GReco.png',
      'route': 'custom_listening', // Connects to ListeningScreen
    },
    {
      'title': 'التواصل',
      'iconSelected':   'assets/images/icon_YCom.png',
      'iconUnselected': 'assets/images/icon_GCom.png',
      'route': 'custom_communication', // 👇 Updated to intercept custom route
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NabeehColors.background,
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
                  _buildAlarmCard(), 
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
          const Text(
            'اهلاً ريم',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: NabeehColors.darkBlue,
            ),
          ),
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: _kBlueGradient,
            ),
            child: Padding(
              padding: const EdgeInsets.all(11),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NabeehColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'حالة الساعة:',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFD4F4E2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'متصلة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: NabeehColors.green,
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: widget.onMoreInfoPressed, 
            child: const Center(
              child: Text(
                'للمزيد من المعلومات',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF21277B),
                  decoration: TextDecoration.underline,
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
        SizedBox(
          height: 260,
          child: PageView.builder(
            padEnds: false, 
            controller: PageController(viewportFraction: 0.58),
            onPageChanged: (i) {
              if (i < _features.length) {
                setState(() => _selectedFeature = i);
              }
            },
            itemCount: _features.length + 1,
            itemBuilder: (context, index) {
              if (index == _features.length) {
                return SizedBox(width: MediaQuery.of(context).size.width * 0.4);
              }

              final isSelected = index == _selectedFeature;
              final f = _features[index];
              return GestureDetector(
                onTap: () {
                  final route = f['route'];
                  
                  // 👇 Custom routing for Listening and STT/TTS Screens
                  if (route == 'custom_listening') {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const ListeningScreen())
                    );
                  } 
                  else if (route == 'custom_communication') {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const SttTtsScreen())
                    );
                  }
                  else if (route != null) {
                    Navigator.pushNamed(context, route);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(left: 15, bottom: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected ? _kBlueGradient : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected 
                          ? Colors.transparent 
                          : NabeehColors.cardBorder.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isSelected ? 0.15 : 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 20,
                        right: 20,
                        child: Image.asset(
                          isSelected ? f['iconSelected']! : f['iconUnselected']!,
                          width: 42,
                          height: 42,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            f['title']!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : NabeehColors.gray,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlarmCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => const RemindersScreen())
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: _kBlueGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: NabeehColors.darkNavy.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset('assets/images/icon_YRima.png', width: 28),
                const SizedBox(width: 10),
                const Text(
                  'المنبّه',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: NabeehColors.yellow
                  ),
                ),
                const Spacer(), 
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'ابدأ يومك بطريقة مختلفة، تنبيه لطيف بالاهتزاز يمنحك استيقاظاً مريحاً بلا إزعاج',
              style: TextStyle(
                fontSize: 15, 
                color: Colors.white, 
                height: 1.6,
                fontWeight: FontWeight.w400
              ),
            ),
          ],
        ),
      ),
    );
  }
}