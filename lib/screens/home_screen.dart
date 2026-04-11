import 'package:flutter/material.dart';

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

// ─── Shared gradient (used in cards, alarm, logo) ─────────────────────────────
const _kBlueGradient = LinearGradient(
  colors: [Color(0xFF181059), Color(0xFF181059), Color(0xFF1773CF)],
  stops: [0.09, 0.30, 1.0],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

// ─── Home Screen ──────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedFeature = 0; // 0=المجموعات

  // Scroll order (LTR PageView):
  // page 0 = المجموعات الصوتية  ← shown first / default
  // page 1 = تسجيل الصوت        ← scroll right once
  // page 2 = التواصل             ← scroll right twice
  final List<Map<String, String>> _features = [
    {
      'title': 'المجموعات\nالصوتية',
      'iconSelected':   'assets/images/icon_Ycato.png',
      'iconUnselected': 'assets/images/icon_GCato.png',
      'route': '/sound-groups',
    },
    {
      'title': 'تسجيل\nالصوت',
      'iconSelected':   'assets/images/icon_YReco.png',
      'iconUnselected': 'assets/images/icon_GReco.png',
      'route': '/sound-recording',
    },
    {
      'title': 'التواصل',
      'iconSelected':   'assets/images/icon_YCom.png',
      'iconUnselected': 'assets/images/icon_GCom.png',
      'route': '/communication',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
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
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
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

  // ── Watch Card ────────────────────────────────────────────────────────────
  Widget _buildWatchCard() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                    colors: [Color.fromARGB(255, 241, 241, 241), Color.fromARGB(255, 243, 243, 243)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color.fromARGB(255, 159, 159, 159)),
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
            onTap: () { /* TODO: go to watch page */ },
            child: const Center(
              child: Text(
                'للمزيد من المعلومات',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: NabeehColors.darkBlue,
                  decoration: TextDecoration.underline,
                  decorationColor: NabeehColors.darkBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Features Section ──────────────────────────────────────────────────────
  Widget _buildFeaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            'كيف يمكنني مساعدتك ؟',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: NabeehColors.darkBlue,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Transform.translate(
          offset: const Offset(80, 0),
          child: SizedBox(
            width: 350,
            height: 250,
            child: PageView.builder(
              controller: PageController(
                viewportFraction: 0.65,
                initialPage: 0,
              ),
              scrollDirection: Axis.horizontal,
              onPageChanged: (pageIndex) {
                setState(() => _selectedFeature = pageIndex);
              },
              itemCount: _features.length,
              itemBuilder: (context, index) {
                final isSelected = index == _selectedFeature;
                final f = _features[index];

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected ? _kBlueGradient : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: NabeehColors.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                            alpha: isSelected ? 0.22 : 0.07),
                        blurRadius: isSelected ? 14 : 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Image.asset(
                          isSelected ? f['iconSelected']! : f['iconUnselected']!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Center(
                        child: Text(
                          f['title']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : NabeehColors.gray,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Alarm Card ────────────────────────────────────────────────────────────
  Widget _buildAlarmCard() {
    return GestureDetector(
      onTap: () { /* TODO: go to alarm page */ },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF181059), Color(0xFF181059), Color(0xFF1773CF)],
            stops: [0.09, 0.30, 1.0],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: NabeehColors.darkNavy.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/icon_YRima.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                const Text(
                  'المنبّه',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: NabeehColors.yellow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'ابدأ يومك بطريقة مختلفة، تنبيه لطيف بالاهتزاز يمنحك استيقاظاً مريحاً بلا إزعاج',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w300,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}