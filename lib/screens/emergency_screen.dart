import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'contacts_screen.dart';
import 'sign_language_player_screen.dart';
import '../services/sign_language_mode.dart';

// ─── Colors ───────────────────────────────────────────────────────────────────
class NabeehColors {
  static const darkBlue = Color(0xFF21277B);
  static const lightBlue = Color(0xFF1773CF);
  static const yellow = Color(0xFFFFD350);
  static const green = Color(0xFF00AA5B);
  static const gray = Color(0xFFA4ACB0);
  static const background = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE5E7EB);
  static const lightBlueBg = Color(0xFFEFF4FF);
}

// ─── Contact Model ────────────────────────────────────────────────────────────
class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relation;

  EmergencyContact({
    this.id = '',
    required this.name,
    required this.phone,
    required this.relation,
  });

  factory EmergencyContact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyContact(
      id: doc.id,
      name: data['Name'] ?? '',
      phone: data['Phone'] ?? '',
      relation: data['Relation'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'Name': name,
    'Phone': phone,
    'Relation': relation,
  };
}

const _kBlueGradient = LinearGradient(
  colors: [Color(0xFF181059), Color(0xFF181059), Color(0xFF1773CF)],
  stops: [0.09, 0.30, 1.0],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

// ─── Emergency Screen ─────────────────────────────────────────────────────────
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  // SOS state
  bool _sosActive = false;
  int _sosCountdown = 5;
  Timer? _sosTimer;

  // SOS pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sosTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

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

  // ── SOS Logic ──────────────────────────────────────────────────────────────
  void _startSOS() {
    setState(() {
      _sosActive = true;
      _sosCountdown = 5;
    });
    _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sosCountdown <= 1) {
        timer.cancel();
        setState(() => _sosActive = false);
        _triggerSOS();
      } else {
        setState(() => _sosCountdown--);
      }
    });
  }

  void _cancelSOS() {
    _sosTimer?.cancel();
    setState(() {
      _sosActive = false;
      _sosCountdown = 5;
    });
  }

  Future<void> _triggerSOS() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري تجهيز نداء الاستغاثة...'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // 1. طلب صلاحية الموقع
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      double? latitude;
      double? longitude;

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        latitude = position.latitude;
        longitude = position.longitude;
      }

      // 2. جلب أرقام جهات الاتصال من Firestore
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('User')
          .doc(uid)
          .collection('EmergencyContacts')
          .get();

      final phones = snapshot.docs
          .map((doc) => doc.data()['Phone'] as String?)
          .whereType<String>()
          .where((phone) => phone.isNotEmpty)
          .toList();

      if (phones.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا توجد جهات اتصال لإرسال النداء إليها'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 3. بناء رسالة الاستغاثة مع رابط الموقع
      final hasLocation = latitude != null && longitude != null;
      final mapsLink = hasLocation
          ? 'https://www.google.com/maps?q=$latitude,$longitude'
          : 'غير متاح';

      final message =
          'أنا في خطر أحتاج إلى المساعدة 🚨\n\nهذا الموقع الخاص بي:\n$mapsLink';

      // 4. فتح تطبيق الرسائل مع تعبئة الأرقام والرسالة مسبقاً
      final separator = Platform.isIOS ? ';' : ',';
      final smsUri = Uri(
        scheme: 'sms',
        path: phones.join(separator),
        queryParameters: {'body': message},
      );

      if (!mounted) return;
      final launched = await launchUrl(smsUri);
      if (!launched) {
        throw Exception('تعذر فتح تطبيق الرسائل');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تجهيز الرسالة: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildContactsButton(),
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'هل أنت في حالة خطر ؟',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF181059),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 75),
                                Center(child: _buildSOSButton()),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 64, bottom: 20, right: 20, left: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'الـطــوارئ',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF181059),
            ),
          ),
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

  // ── Contacts Button ───────────────────────────────────────────────────────
  Widget _buildContactsButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => _handleTap(
          'assets/videos/sign_contacts.mp4',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ContactsScreen()),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF181059), width: 1.2),
          ),
          child: Row(
            children: [
              const ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Color(0xFF181059),
                  BlendMode.srcIn,
                ),
                child: Text('👥', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 16),
              const Text(
                'جهات الاتصال',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181059),
                ),
              ),
              const Spacer(),
              const Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: Color(0xFF181059),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SOS Button ────────────────────────────────────────────────────────────
  Widget _buildSOSButton() {
    return GestureDetector(
      onTap: _sosActive ? _cancelSOS : _startSOS,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outermost pulse ring
              Transform.scale(
                scale: _pulseAnim.value * 1.3,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.08),
                  ),
                ),
              ),
              // Middle pulse ring
              Transform.scale(
                scale: _pulseAnim.value * 1.15,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.15),
                  ),
                ),
              ),
              // Main button
              Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE53935), // Slightly brighter red
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent,
                      blurRadius: 25,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: _sosActive
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_sosCountdown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'اضغط للإلغاء',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
