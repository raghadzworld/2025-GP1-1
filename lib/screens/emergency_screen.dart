import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  final String email;
  final String relation;

  EmergencyContact({
    this.id = '',
    required this.name,
    required this.email,
    required this.relation,
  });

  factory EmergencyContact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmergencyContact(
      id: doc.id,
      name: data['Name'] ?? '',
      email: data['Email'] ?? '',
      relation: data['Relation'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'Name': name,
    'Email': email,
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
  final List<EmergencyContact> _contacts = [];

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
    _loadContacts();
  }

  CollectionReference<Map<String, dynamic>>? get _contactsRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('User')
        .doc(uid)
        .collection('EmergencyContacts');
  }

  Future<void> _loadContacts() async {
    try {
      final ref = _contactsRef;
      if (ref == null) return;
      final snapshot = await ref.get();
      if (!mounted) return;
      setState(() {
        _contacts
          ..clear()
          ..addAll(snapshot.docs.map(EmergencyContact.fromFirestore));
      });
    } catch (_) {
      // تبقى القائمة فارغة إذا فشل الجلب
    }
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

  Future<void> _triggerSOS() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('جاري إرسال نداء الاستغاثة...'),
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

      // 2. جلب بيانات المستخدم والإيميلات من Firestore
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(uid)
          .get();
      String userName = (userDoc.data()?['FullName'] as String? ?? '').trim();
      if (userName.isEmpty) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser?.email != null) {
          final query = await FirebaseFirestore.instance
              .collection('User')
              .where('Email', isEqualTo: currentUser!.email)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            userName = (query.docs.first.data()['FullName'] as String? ?? '').trim();
          }
        }
      }
      if (userName.isEmpty) userName = 'مستخدم نبيه';

      final snapshot = await FirebaseFirestore.instance
          .collection('User')
          .doc(uid)
          .collection('EmergencyContacts')
          .get();

      final emails = snapshot.docs
          .map((doc) => doc.data()['Email'] as String?)
          .whereType<String>()
          .toList();

      if (emails.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا توجد جهات اتصال لإرسال النداء إليها'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 3. إرسال إيميل لكل جهة اتصال عبر EmailJS REST API
      const emailjsServiceId  = 'service_z8s2iye';
      const emailjsTemplateId = 'template_5skt4yr';
      const emailjsPublicKey  = 'iTX-OPPPTV27wvJyw';
      const emailjsPrivateKey = '-cAevJ-wpLtQbsPtHHn6S';

      final hasLocation = latitude != null && longitude != null;
      final mapsLink = hasLocation
          ? 'https://www.google.com/maps?q=$latitude,$longitude'
          : 'غير متاح';

      for (final email in emails) {
        final response = await http.post(
          Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'service_id':  emailjsServiceId,
            'template_id': emailjsTemplateId,
            'user_id':     emailjsPublicKey,
            'accessToken': emailjsPrivateKey,
            'template_params': {
              'to_email':   email,
              'name':       userName,
              'user_name':  userName,
              'latitude':   latitude?.toString() ?? 'غير متاح',
              'longitude':  longitude?.toString() ?? 'غير متاح',
              'maps_link':  mapsLink,
            },
          }),
        );

        if (response.statusCode != 200) {
          throw Exception('EmailJS error: ${response.body}');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال نداء الاستغاثة إلى جهات الاتصال'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل الإرسال: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(email.trim());
  }

  // ── Add Contact Sheet ──────────────────────────────────────────────────────
  void _showAddContactSheet() {
    if (_contacts.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن إضافة أكثر من جهتَي اتصال'),
          backgroundColor: Color(0xFF181059),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Directionality(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 24),
              const Text(
                'إضافة جهة اتصال:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181059),
                ),
              ),
              const SizedBox(height: 24),
              _buildFormField(label: 'الاسم:', controller: nameCtrl),
              const SizedBox(height: 20),
              _buildFormField(
                label: 'الايميل:',
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                errorText: emailCtrl.text.isNotEmpty && !_isValidEmail(emailCtrl.text)
                    ? 'صيغة البريد الإلكتروني غير صحيحة'
                    : null,
              ),
              const SizedBox(height: 20),
              _buildFormField(label: 'جهة القرابة:', controller: relationCtrl),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF181059), Color(0xFF1773CF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: TextButton(
                  onPressed: () async {
                    setSheetState(() {});
                    if (nameCtrl.text.trim().isEmpty ||
                        emailCtrl.text.trim().isEmpty ||
                        relationCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى تعبئة جميع الحقول')),
                      );
                      return;
                    }
                    if (!_isValidEmail(emailCtrl.text)) return;
                    try {
                      final newContact = EmergencyContact(
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        relation: relationCtrl.text.trim(),
                      );
                      final docRef = await _contactsRef!.add(newContact.toFirestore());
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      if (mounted) {
                        setState(() => _contacts.add(EmergencyContact(
                          id: docRef.id,
                          name: newContact.name,
                          email: newContact.email,
                          relation: newContact.relation,
                        )));
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('حدث خطأ: $e')),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'إضافة',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Back button
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: Colors.redAccent, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'تراجع',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _deleteContact(int index) async {
    final contact = _contacts[index];
    if (contact.id.isNotEmpty) {
      await _contactsRef?.doc(contact.id).delete();
    }
    if (mounted) setState(() => _contacts.removeAt(index));
  }

  void _selectContactForEdit() {
    if (_contacts.isEmpty) return;
    if (_contacts.length == 1) {
      _showEditContactSheet(_contacts.first, 0);
      return;
    }
    _showContactSelectorSheet(onSelect: (index) {
      Navigator.pop(context);
      _showEditContactSheet(_contacts[index], index);
    });
  }

  void _selectContactForDelete() {
    if (_contacts.isEmpty) return;
    if (_contacts.length == 1) {
      _deleteContact(0);
      return;
    }
    _showContactSelectorSheet(onSelect: (index) {
      Navigator.pop(context);
      _deleteContact(index);
    });
  }

  void _showContactSelectorSheet({required void Function(int index) onSelect}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                'اختر جهة الاتصال:',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181059),
                ),
              ),
              const SizedBox(height: 16),
              ..._contacts.asMap().entries.map((entry) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: NabeehColors.lightBlueBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF181059), size: 22),
                ),
                title: Text(
                  entry.value.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF181059)),
                ),
                subtitle: Text(
                  'جهة القرابة: ${entry.value.relation}',
                  style: const TextStyle(fontSize: 12, color: NabeehColors.gray),
                ),
                onTap: () => onSelect(entry.key),
              )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditContactSheet(EmergencyContact contact, int index) {
    final nameCtrl = TextEditingController(text: contact.name);
    final emailCtrl = TextEditingController(text: contact.email);
    final relationCtrl = TextEditingController(text: contact.relation);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Directionality(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 24),
              const Text(
                'تعديل جهة الاتصال:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181059),
                ),
              ),
              const SizedBox(height: 24),
              _buildFormField(label: 'الاسم:', controller: nameCtrl),
              const SizedBox(height: 20),
              _buildFormField(
                label: 'الايميل:',
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                errorText: emailCtrl.text.isNotEmpty && !_isValidEmail(emailCtrl.text)
                    ? 'صيغة البريد الإلكتروني غير صحيحة'
                    : null,
              ),
              const SizedBox(height: 20),
              _buildFormField(label: 'جهة القرابة:', controller: relationCtrl),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF181059), Color(0xFF1773CF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: TextButton(
                  onPressed: () async {
                    setSheetState(() {});
                    if (nameCtrl.text.trim().isEmpty ||
                        emailCtrl.text.trim().isEmpty ||
                        relationCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى تعبئة جميع الحقول')),
                      );
                      return;
                    }
                    if (!_isValidEmail(emailCtrl.text)) return;
                    final updated = EmergencyContact(
                      id: contact.id,
                      name: nameCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      relation: relationCtrl.text.trim(),
                    );
                    if (contact.id.isNotEmpty) {
                      await _contactsRef?.doc(contact.id).update(updated.toFirestore());
                    }
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (mounted) setState(() => _contacts[index] = updated);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'حفظ',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: Colors.redAccent, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'تراجع',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF181059),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: 'اكتب هنا',
            hintStyle: const TextStyle(color: NabeehColors.gray, fontSize: 14),
            errorText: errorText,
            errorStyle: const TextStyle(fontSize: 12),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: errorText != null ? Colors.red : NabeehColors.cardBorder,
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: errorText != null ? Colors.red : NabeehColors.lightBlue,
                width: 2,
              ),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'جهات الاتصال:',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF181059),
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: _contacts.isNotEmpty ? _selectContactForEdit : null,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            minimumSize: const Size(90, 44),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: const BorderSide(color: Color(0xFF181059), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text(
                            'تعديل',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF181059),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _contacts.isNotEmpty ? _selectContactForDelete : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            minimumSize: const Size(90, 44),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: const BorderSide(color: Colors.redAccent, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text(
                            'حذف',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._contacts.map((c) => _buildContactTile(c)),
                    if (_contacts.length < 2) _buildAddContactButton(),
                    const SizedBox(height: 40),
                    const Text(
                      'هل أنت في حالة خطر ؟',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF181059),
                      ),
                    ),
                    const SizedBox(height: 75),
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
            'الـطــوارئ',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
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


  // ── Contact Tile ──────────────────────────────────────────────────────────
  Widget _buildContactTile(EmergencyContact contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NabeehColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar on the right (in RTL)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFEEF0F8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFF181059),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Info on the left (in RTL)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF181059),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'جهة القرابة : ${contact.relation}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: NabeehColors.gray,
                  ),
                ),
              ],
            ),
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color.fromARGB(255, 235, 233, 229)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF181059),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'اضف جهة اتصال',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF181059),
                  fontWeight: FontWeight.w500,
                ),
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
