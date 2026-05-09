import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;
import 'nabeeh_colors.dart';

class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  // State variables for mic toggle and detection
  bool isListening = true;
  String detectedSound = 'جاري الاستماع للبيئة...';

  @override
  void initState() {
    super.initState();
    // Setup repeating animation for the soundwaves
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  // Toggle function for the microphone
  void _toggleListening() {
    setState(() {
      isListening = !isListening;
      if (isListening) {
        _waveController.repeat();
        detectedSound = 'جاري الاستماع للبيئة...';
      } else {
        _waveController.stop();
        detectedSound = 'الميكروفون متوقف';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFDDEEF8), Color(0xFFF2F9FE), Colors.white],
              stops: [0.0, 0.35, 0.6],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 60),
                _buildMicAndWaves(),
                const Spacer(),
                _buildCurrentSoundCard(),
                const SizedBox(height: 40),
              ],
            ),
          ),
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
          // 1. Grouped Back Button and Title (Anchored to the Right in RTL)
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
                      color: const Color(
                        0xFF181059,
                      ), // 👈 Changed the border to dark blue!
                      width: 1.5,
                    ),
                  ),
                  child: const Directionality(
                    textDirection: TextDirection.ltr,
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF181059),
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'الاستشعــار الصـوتي',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181059),
                ),
              ),
            ],
          ),

          // 2. Sign Language Gesture Button (Anchored to the Left in RTL)
          GestureDetector(
            onTap: () {
              // Add your gesture button action here
            },
            child: Container(
              width: 44, // 👈 Consistently sized to 44
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF181059),
                    Color(0xFF181059),
                    Color(0xFF1773CF),
                  ],
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
                padding: const EdgeInsets.all(
                  10,
                ), // 👈 Consistently padded to 10
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

  Widget _buildMicAndWaves() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Interactive Mic Icon
        GestureDetector(
          onTap: _toggleListening,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening
                  ? NabeehColors.lightBlue.withValues(alpha: 0.1)
                  : NabeehColors.slate200.withValues(alpha: 0.5),
              boxShadow: isListening
                  ? [
                      BoxShadow(
                        color: NabeehColors.lightBlue.withValues(alpha: 0.2),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Icon(
                isListening ? LucideIcons.mic : LucideIcons.micOff,
                size: 50,
                color: isListening
                    ? NabeehColors.lightBlue
                    : NabeehColors.slate400,
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),

        // Animated Sound Waves (stops when mic is off)
        SizedBox(
          height: 60,
          child: AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(15, (index) {
                  final offset = index * 0.4;
                  // If not listening, flatline the waves
                  final heightVal = isListening
                      ? (math.sin(
                                  (_waveController.value * 2 * math.pi) +
                                      offset,
                                ) +
                                1) /
                            2
                      : 0.0;
                  final barHeight = 10 + (heightVal * 50);

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 6,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: isListening
                          ? NabeehColors.lightBlue.withValues(alpha: 0.8)
                          : NabeehColors.slate300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          isListening
              ? 'جاري تحليل الأصوات من حولك...'
              : 'الاستماع متوقف حالياً',
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isListening ? NabeehColors.slate500 : NabeehColors.slate400,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSoundCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color.fromARGB(255, 235, 233, 229)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isListening ? LucideIcons.activity : LucideIcons.moon,
                  color: isListening
                      ? const Color(0xFF181059)
                      : NabeehColors.slate400,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'الصوت المكتشف حالياً',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: NabeehColors.slate500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    detectedSound,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: isListening ? 22 : 18,
                      fontWeight: FontWeight.bold,
                      color: isListening
                          ? NabeehColors.darkBlue
                          : NabeehColors.slate400,
                    ),
                  ),
                ),
                // Replaced the "Change" button with a live indicator
                if (isListening)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
