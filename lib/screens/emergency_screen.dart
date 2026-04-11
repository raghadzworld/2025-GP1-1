import 'package:flutter/material.dart';
import 'dart:async';

// ─── Colors (same file or import from shared) ─────────────────────────────────
class NabeehColors {
  static const darkBlue = Color(0xFF21277B);
  static const lightBlue = Color(0xFF1773CF);
  static const yellow = Color(0xFFFFD350);
  static const green = Color(0xFF00AA5B);
  static const gray = Color(0xFFA4ACB0);
  static const background = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE5E7EB);
}

// ─── Contact Model ────────────────────────────────────────────────────────────
class EmergencyContact {
  final String name;
  final String email;
  final String relation;

  EmergencyContact({
    required this.name,
    required this.email,
    required this.relation,
  });
}

// ─── Emergency Screen ─────────────────────────────────────────────────────────
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  bool _numbersExpanded = false;
  final List<EmergencyContact> _contacts = [];

  // SOS state
  bool _sosActive = false;
  int _sosCountdown = 5;
  Timer? _sosTimer;

  // SOS pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  final List<Map<String, String>> _emergencyNumbers = [
    {'name': 'مركز القيادة والسيطرة والتحكم', 'number': '991'},
    {'name': 'الدوريات الامنية', 'number': '999'},
    {'name': 'الهلال الأحمر', 'number': '997'},
    {'name': 'الدفاع المدني', 'number': '998'},
  ];

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

  void _triggerSOS() {
    // TODO: Send alert to contacts via backend
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إرسال نداء الاستغاثة إلى جهات الاتصال'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ── Add Contact Sheet ──────────────────────────────────────────────────────
  void _showAddContactSheet() {
    if (_contacts.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن إضافة أكثر من جهتَي اتصال'),
          backgroundColor: NabeehColors.darkBlue,
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final relationCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            top: 24,
            right: 24,
            left: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NabeehColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'إضافة جهة اتصال:',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: NabeehColors.darkBlue,
                ),
              ),
              const SizedBox(height: 20),
              _buildFormField(label: 'الاسم:', controller: nameCtrl),
              const SizedBox(height: 16),
              _buildFormField(
                  label: 'الايميل:',
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildFormField(
                  label: 'جهة القرابة:', controller: relationCtrl),
              const SizedBox(height: 28),
              // Add button
              OutlinedButton(
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty &&
                      emailCtrl.text.isNotEmpty &&
                      relationCtrl.text.isNotEmpty) {
                    setState(() {
                      _contacts.add(EmergencyContact(
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        relation: relationCtrl.text.trim(),
                      ));
                    });
                    Navigator.pop(ctx);
                  }
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: NabeehColors.lightBlue),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('إضافة',
                    style: TextStyle(
                        color: NabeehColors.lightBlue,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              // Back button
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('تراجع',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: NabeehColors.darkBlue)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: 'اكتب هنا',
            hintStyle: const TextStyle(color: NabeehColors.gray, fontSize: 13),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: NabeehColors.cardBorder),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide:
                  BorderSide(color: NabeehColors.lightBlue, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.white,
        child: Column(
          children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildEmergencyNumbersCard(),
                  const SizedBox(height: 24),
                  const Text(
                    'جهات الاتصال:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NabeehColors.darkBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._contacts.map((c) => _buildContactTile(c)),
                  if (_contacts.length < 2)
                    _buildAddContactButton(),
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      'هل انت في حالة خطر ؟',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: NabeehColors.darkBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(child: _buildSOSButton()),
                  const SizedBox(height: 40),
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
      padding:
          const EdgeInsets.only(top: 56, bottom: 24, right: 20, left: 20),
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
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: NabeehColors.darkBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hearing_rounded,
                color: Colors.white, size: 24),
          ),
          const Text(
            'الطوارئ',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: NabeehColors.darkBlue,
            ),
          ),
        ],
      ),
    );
  }

  // ── Emergency Numbers Card ────────────────────────────────────────────────
  Widget _buildEmergencyNumbersCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NabeehColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row (tap to expand)
          GestureDetector(
            onTap: () =>
                setState(() => _numbersExpanded = !_numbersExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      AnimatedRotation(
                        turns: _numbersExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(Icons.arrow_drop_down,
                            color: NabeehColors.lightBlue, size: 28),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text(
                        'ارقام الطوارئ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: NabeehColors.darkBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.crisis_alert_rounded,
                            color: NabeehColors.lightBlue, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expandable numbers list
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _numbersExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1, color: NabeehColors.cardBorder),
                ..._emergencyNumbers.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Number badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF4FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item['number']!,
                              style: const TextStyle(
                                color: NabeehColors.lightBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          // Name
                          Text(
                            item['name']!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: NabeehColors.darkBlue,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Contact Tile ──────────────────────────────────────────────────────────
  Widget _buildContactTile(EmergencyContact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NabeehColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded,
                color: NabeehColors.lightBlue, size: 22),
          ),
          // Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                contact.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: NabeehColors.lightBlue,
                ),
              ),
              Text(
                'جهة القرابة : ${contact.relation}',
                style: const TextStyle(
                    fontSize: 12, color: NabeehColors.gray),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Add Contact Button ────────────────────────────────────────────────────
  Widget _buildAddContactButton() {
    return GestureDetector(
      onTap: _showAddContactSheet,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NabeehColors.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: NabeehColors.lightBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            const Text(
              'اضف جهة اتصال',
              style: TextStyle(
                fontSize: 15,
                color: NabeehColors.darkBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
                scale: _pulseAnim.value * 1.25,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.08),
                  ),
                ),
              ),
              // Middle pulse ring
              Transform.scale(
                scale: _pulseAnim.value * 1.1,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.14),
                  ),
                ),
              ),
              // Main button
              Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent,
                      blurRadius: 20,
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
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'اضغط للإلغاء',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        )
                      : const Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
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