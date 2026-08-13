import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:math' as math;
import 'dart:async'; 
import 'package:record/record.dart';
import 'nabeeh_colors.dart';
// 👇 Added Sign Language Imports
import '../services/sign_language_mode.dart';
import 'sign_language_player_screen.dart';

class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  final _audioRecorder = AudioRecorder();
  
  Timer? _amplitudeTimer;
  double _audioLevel = 0.0;

  bool isListening = false;
  String detectedSound = 'جاري التحقق من الميكروفون...';

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _startInitialListening();
  }

  // 👇 Added Sign Language Helper
  void _handleTap(String videoAsset, VoidCallback action) {
    if (signLanguageModeNotifier.value) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => SignLanguagePlayerScreen(
          videoAsset: videoAsset,
          onFinished: action,
        ),
      );
    } else {
      action();
    }
  }

  void _startAmplitudeTimer() {
    _amplitudeTimer?.cancel(); 
    
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      if (await _audioRecorder.isRecording()) {
        final amp = await _audioRecorder.getAmplitude();
        
        final double minDb = -45.0; 
        double normalized = (amp.current - minDb) / (0.0 - minDb);
        
        if (mounted) {
          setState(() {
            _audioLevel = normalized.clamp(0.0, 1.0);
          });
        }
      }
    });
  }

  Future<void> _startInitialListening() async {
    bool hasPermission = await _audioRecorder.hasPermission();
    if (hasPermission) {
      await _audioRecorder.startStream(const RecordConfig());
      _startAmplitudeTimer(); 
      
      setState(() {
        isListening = true;
        detectedSound = 'جاري الاستماع للبيئة...';
        _waveController.repeat();
      });
    } else {
      setState(() {
        isListening = false;
        detectedSound = 'يرجى تفعيل صلاحية الميكروفون';
      });
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _amplitudeTimer?.cancel(); 
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (isListening) {
      _amplitudeTimer?.cancel(); 
      await _audioRecorder.stop();
      
      setState(() {
        isListening = false;
        _audioLevel = 0.0; 
        _waveController.stop();
        detectedSound = 'الميكروفون متوقف';
      });
    } else {
      bool hasPermission = await _audioRecorder.hasPermission();
      if (hasPermission) {
        await _audioRecorder.startStream(const RecordConfig());
        _startAmplitudeTimer(); 
        
        setState(() {
          isListening = true;
          _waveController.repeat();
          detectedSound = 'جاري الاستماع للبيئة...';
        });
      } else {
        setState(() {
          detectedSound = 'يرجى تفعيل صلاحية الميكروفون';
        });
      }
    }
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
                const SizedBox(height: 110), 
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
                  color: const Color(0xFF181059),
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
          const Expanded(
            child: Text(
              'الاستشعار الصوتي',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF181059),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 👇 Replaced with active Toggle logic
          ValueListenableBuilder<bool>(
            valueListenable: signLanguageModeNotifier,
            builder: (context, isActive, _) => GestureDetector(
              onTap: () {
                signLanguageModeNotifier.value = !isActive;
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF0B4D2C),
                            Color(0xFF0B4D2C),
                            NabeehColors.green,
                          ],
                          stops: [0.09, 0.30, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : const LinearGradient(
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
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    'assets/images/icon_signLan.png',
                    color: Colors.white,
                    colorBlendMode: BlendMode.srcIn,
                    fit: BoxFit.contain,
                  ),
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
        GestureDetector(
          // 👇 Wrapped Mic Toggle action with Sign Language
          onTap: () => _handleTap('assets/videos/sign_start_listening.mp4', () => _toggleListening()),
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
                  
                  final baseRipple = (math.sin(
                              (_waveController.value * 2 * math.pi) + offset) +
                          1) /
                      2;
                  
                  final heightVal = isListening 
                      ? baseRipple * (_audioLevel + 0.1) 
                      : 0.0;
                      
                  final barHeight = 10 + (heightVal * 50);

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
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