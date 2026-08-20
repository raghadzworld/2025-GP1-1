import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'emergency_screen.dart' show EmergencyContact;
import 'sign_language_player_screen.dart';
import '../services/sign_language_mode.dart';

const _kContactsGray = Color(0xFFA4ACB0);
const _kContactsCardBorder = Color(0xFFE5E7EB);

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final List<EmergencyContact> _contacts = [];
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
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

  String _sanitizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 10 ? digits.substring(0, 10) : digits;
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^05\d{8}$').hasMatch(_sanitizePhone(phone));
  }

  // ── Add Contact Sheet ──────────────────────────────────────────────────────
  void _showAddContactSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relationCtrl = TextEditingController();

    String? nameError;
    String? phoneError;
    String? relationError;

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
          child: SingleChildScrollView(
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
                      color: _kContactsCardBorder,
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
                _buildFormField(
                  label: 'الاسم:',
                  controller: nameCtrl,
                  icon: Icons.person_outline,
                  errorText: nameError,
                  onChanged: (_) {
                    if (nameError != null) setSheetState(() => nameError = null);
                  },
                ),
                const SizedBox(height: 20),
                _buildFormField(
                  label: 'رقم الجوال:',
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  icon: Icons.phone_outlined,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  errorText: phoneError,
                  onChanged: (_) {
                    if (phoneError != null) setSheetState(() => phoneError = null);
                  },
                ),
                const SizedBox(height: 20),
                _buildFormField(
                  label: 'جهة القرابة:',
                  controller: relationCtrl,
                  icon: Icons.people_outline,
                  errorText: relationError,
                  onChanged: (_) {
                    if (relationError != null) {
                      setSheetState(() => relationError = null);
                    }
                  },
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Container(
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
                            final name = nameCtrl.text.trim();
                            final phone = phoneCtrl.text.trim();
                            final relation = relationCtrl.text.trim();

                            setSheetState(() {
                              nameError =
                                  name.isEmpty ? 'الرجاء إدخال الاسم' : null;
                              phoneError = phone.isEmpty
                                  ? 'الرجاء إدخال رقم الجوال'
                                  : !_isValidPhone(phone)
                                      ? 'يجب أن يتكون الرقم من 10 أرقام ويبدأ بـ 05'
                                      : null;
                              relationError = relation.isEmpty
                                  ? 'الرجاء إدخال جهة القرابة'
                                  : null;
                            });

                            if (nameError != null ||
                                phoneError != null ||
                                relationError != null) {
                              return;
                            }

                            try {
                              final newContact = EmergencyContact(
                                name: name,
                                phone: _sanitizePhone(phone),
                                relation: relation,
                              );
                              final docRef = await _contactsRef!.add(
                                newContact.toFirestore(),
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              if (mounted) {
                                setState(
                                  () => _contacts.add(
                                    EmergencyContact(
                                      id: docRef.id,
                                      name: newContact.name,
                                      phone: newContact.phone,
                                      relation: newContact.relation,
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('حدث خطأ: $e')),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            alignment: Alignment.center,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'إضافة',
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          side: const BorderSide(
                            color: Color.fromARGB(255, 200, 198, 195),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, color: Colors.grey, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'إلغاء',
                              style: TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                                color: Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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

  Future<void> _confirmDeleteContact(EmergencyContact contact, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Text(
                'حذف جهة الاتصال',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف "${contact.name}"؟',
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 15),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: OutlinedButton.styleFrom(
                      fixedSize: const Size.fromHeight(50),
                      padding: EdgeInsets.zero,
                      side: const BorderSide(
                        color: Colors.redAccent,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.trash2,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'حذف نهائي',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    style: TextButton.styleFrom(
                      fixedSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(
                          color: Color.fromARGB(255, 200, 198, 195),
                        ),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.x, color: Color(0xFF64748B), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'إلغاء',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(width: 22),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) _deleteContact(index);
  }

  void _showEditContactSheet(EmergencyContact contact, int index) {
    final nameCtrl = TextEditingController(text: contact.name);
    final phoneCtrl = TextEditingController(text: contact.phone);
    final relationCtrl = TextEditingController(text: contact.relation);

    String? nameError;
    String? phoneError;
    String? relationError;

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
          child: SingleChildScrollView(
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
                      color: _kContactsCardBorder,
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
                _buildFormField(
                  label: 'الاسم:',
                  controller: nameCtrl,
                  icon: Icons.person_outline,
                  errorText: nameError,
                  onChanged: (_) {
                    if (nameError != null) setSheetState(() => nameError = null);
                  },
                ),
                const SizedBox(height: 20),
                _buildFormField(
                  label: 'رقم الجوال:',
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  icon: Icons.phone_outlined,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  errorText: phoneError,
                  onChanged: (_) {
                    if (phoneError != null) setSheetState(() => phoneError = null);
                  },
                ),
                const SizedBox(height: 20),
                _buildFormField(
                  label: 'جهة القرابة:',
                  controller: relationCtrl,
                  icon: Icons.people_outline,
                  errorText: relationError,
                  onChanged: (_) {
                    if (relationError != null) {
                      setSheetState(() => relationError = null);
                    }
                  },
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Container(
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
                            final name = nameCtrl.text.trim();
                            final phone = phoneCtrl.text.trim();
                            final relation = relationCtrl.text.trim();

                            setSheetState(() {
                              nameError =
                                  name.isEmpty ? 'الرجاء إدخال الاسم' : null;
                              phoneError = phone.isEmpty
                                  ? 'الرجاء إدخال رقم الجوال'
                                  : !_isValidPhone(phone)
                                      ? 'يجب أن يتكون الرقم من 10 أرقام ويبدأ بـ 05'
                                      : null;
                              relationError = relation.isEmpty
                                  ? 'الرجاء إدخال جهة القرابة'
                                  : null;
                            });

                            if (nameError != null ||
                                phoneError != null ||
                                relationError != null) {
                              return;
                            }

                            final updated = EmergencyContact(
                              id: contact.id,
                              name: name,
                              phone: _sanitizePhone(phone),
                              relation: relation,
                            );
                            if (contact.id.isNotEmpty) {
                              await _contactsRef
                                  ?.doc(contact.id)
                                  .update(updated.toFirestore());
                            }
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (mounted) {
                              setState(() => _contacts[index] = updated);
                            }
                          },
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            alignment: Alignment.center,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.save,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'حفظ',
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          side: const BorderSide(
                            color: Color.fromARGB(255, 200, 198, 195),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, color: Colors.grey, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'إلغاء',
                              style: TextStyle(
                                fontFamily: 'IBMPlexSansArabic',
                                color: Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Form Field with unified red error-box style (matches AddEditCategoryScreen) ──
  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
    IconData? icon,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    ValueChanged<String>? onChanged,
  }) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: const Color(0xFF181059)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF181059),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLengthEnforcement: maxLength != null
              ? MaxLengthEnforcement.enforced
              : null,
          textAlign: TextAlign.right,
          onChanged: onChanged,
          decoration: InputDecoration(
            counterText: maxLength != null ? '' : null,
            hintText: 'اكتب هنا',
            hintStyle: const TextStyle(color: _kContactsGray, fontSize: 14),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: hasError
                    ? Colors.red.withValues(alpha: 0.5)
                    : _kContactsCardBorder,
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: hasError
                    ? Colors.red.withValues(alpha: 0.6)
                    : const Color(0xFF1773CF),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 0,
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertCircle, size: 14, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorText,
                    style: const TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredContacts = _contacts.asMap().entries.where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.value.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildContactsCountBadge(),
                        const SizedBox(height: 12),
                        _buildSearchField(),
                        const SizedBox(height: 16),
                        if (filteredContacts.isEmpty &&
                            _searchQuery.trim().isNotEmpty)
                          _buildNoSearchResults()
                        else
                          ...filteredContacts.map(
                            (e) => _buildContactTile(e.value, e.key),
                          ),
                      ],
                    ),
                  ),
                ),
                _buildAddContactButton(),
              ],
            ),
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
              const Text(
                'جهات الاتصال',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181059),
                ),
              ),
            ],
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
                            Color(0xFF00AA5B),
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

  // ── No Search Results ────────────────────────────────────────────────────
  Widget _buildNoSearchResults() {
    final bool keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Padding(
      padding: EdgeInsets.only(top: keyboardOpen ? 40 : 180),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 42,
              color: _kContactsGray,
            ),
            const SizedBox(height: 12),
            const Text(
              'لا توجد جهات اتصال مطابقة',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                color: _kContactsGray,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Contact Tile ──────────────────────────────────────────────────────────
  Widget _buildContactTile(EmergencyContact contact, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF181059), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1773CF).withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                        color: _kContactsGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _handleTap(
                    'assets/videos/sign_edit_contact.mp4',
                    () => _showEditContactSheet(contact, index),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF181059),
                        width: 1.2,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.edit2,
                          size: 16,
                          color: Color(0xFF181059),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'تعديل',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF181059),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _handleTap(
                    'assets/videos/sign_delete_contact.mp4',
                    () => _confirmDeleteContact(contact, index),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent, width: 1.2),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.trash2,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'حذف',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Add Contact Button (ثابت أسفل الشاشة، يرتفع فوق الكيبورد تلقائياً) ──────
  Widget _buildAddContactButton() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Container(
        height: 60,
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
        child: TextButton.icon(
          onPressed: () => _handleTap(
            'assets/videos/sign_add_contact.mp4',
            _showAddContactSheet,
          ),
          icon: const Icon(LucideIcons.plus, color: Colors.white),
          label: const Text(
            'إضافة جهة اتصال جديدة',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              color: Colors.white,
              letterSpacing: 2,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  // ── Search Field ──────────────────────────────────────────────────────────
  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _searchFocusNode.hasFocus
              ? const Color(0xFF181059)
              : _kContactsCardBorder,
        ),
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocusNode,
        onChanged: (value) => setState(() => _searchQuery = value),
        textAlign: TextAlign.right,
        style: const TextStyle(color: Color(0xFF181059), fontSize: 15),
        decoration: InputDecoration(
          hintText: 'ابحث عن جهة اتصال...',
          hintStyle: const TextStyle(color: _kContactsGray, fontSize: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF181059),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: _kContactsGray,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  // ── Contacts Count Badge ──────────────────────────────────────────────────
  Widget _buildContactsCountBadge() {
    final count = _contacts.length;
    final label = count == 0
        ? 'لا توجد جهات اتصال'
        : count == 1
        ? 'جهة اتصال واحدة'
        : '$count جهات اتصال';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF181059)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF181059),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF181059),
            ),
          ),
        ],
      ),
    );
  }
}
