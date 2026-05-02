import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_reminder_screen.dart';
import 'nabeeh_colors.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _deleteReminder(String reminderId) async {
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('User')
          .doc(currentUser!.uid)
          .collection('Reminders')
          .doc(reminderId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'تم حذف المنبه بنجاح',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء الحذف: $e',
              style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleReminderStatus(
    String reminderId,
    bool currentStatus,
  ) async {
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('User')
          .doc(currentUser!.uid)
          .collection('Reminders')
          .doc(reminderId)
          .update({'isEnabled': !currentStatus});
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  void _confirmDelete(String reminderId) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(LucideIcons.alertTriangle, color: Colors.red),
                SizedBox(width: 10),
                Text(
                  'حذف المنبه',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            content: const Text(
              'هل أنت متأكد من رغبتك في حذف هذا المنبه؟',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 16),
            ),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            actions: [
              Row(
                children: [
                  // 1. Delete Button (Right Side in RTL)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteReminder(reminderId);
                      },
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
                            'حذف',
                            style: TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 2. Cancel Button (Left Side in RTL)
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        fixedSize: const Size.fromHeight(50),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Color.fromARGB(255, 235, 233, 229),
                          ),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.x,
                            color: NabeehColors.slate500,
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'إلغاء',
                            style: TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              color: NabeehColors.slate500,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
        );
      },
    );
  }

  void _editAlarm(String reminderId, Map<String, dynamic> currentData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddReminderScreen(
          reminderId: reminderId,
          existingData: currentData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 40),

              Expanded(
                child: currentUser == null
                    ? const Center(
                        child: Text(
                          'الرجاء تسجيل الدخول لعرض المنبهات',
                          style: TextStyle(fontFamily: 'IBMPlexSansArabic'),
                        ),
                      )
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('User')
                            .doc(currentUser!.uid)
                            .collection('Reminders')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: NabeehColors.darkBlue,
                              ),
                            );
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return _buildEmptyState();
                          }

                          final reminders = snapshot.data!.docs;

                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                ...reminders.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  return _buildAlarmCard(doc.id, data);
                                }),
                                const SizedBox(height: 8),
                                _buildAddButton(),
                                const SizedBox(height: 40),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(LucideIcons.bellOff, size: 80, color: NabeehColors.slate300),
          const SizedBox(height: 20),
          const Text(
            'لا توجد منبهات حالياً',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 18,
              color: NabeehColors.slate500,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 40),
          _buildAddButton(),
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
                'المنبهات',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181059),
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    NabeehColors.darkNavy,
                    NabeehColors.darkNavy,
                    NabeehColors.lightBlue,
                  ],
                  stops: [0.09, 0.30, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
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

  Widget _buildAlarmCard(String reminderId, Map<String, dynamic> alarm) {
    final bool isActive = alarm['isEnabled'] ?? false;
    final String timeString = alarm['time'] ?? '00:00';
    final String label = alarm['label'] ?? 'منبه';

    final List<dynamic> daysArray = alarm['daysActive'] ?? [];

    // 👇 Returns empty string if no days, avoiding "مرة واحدة"
    final String daysText = daysArray.isEmpty ? '' : daysArray.join('، ');

    // 👇 If daysText is empty, just show the label. Otherwise show Label • Days
    final String bottomText = daysText.isEmpty ? label : '$label • $daysText';

    final bool isAm = timeString.contains('ص');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isActive ? NabeehColors.background : NabeehColors.slate50,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isActive ? const Color(0xFF181059) : NabeehColors.slate100,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: NabeehColors.lightBlue.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label above the time
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? NabeehColors.lightBlue
                          : NabeehColors.slate400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        timeString
                            .replaceAll('ص', '')
                            .replaceAll('م', '')
                            .trim(),
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? NabeehColors.darkBlue
                              : NabeehColors.slate400,
                          letterSpacing: -2,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        isAm ? LucideIcons.sun : LucideIcons.moon,
                        size: 22,
                        color: isActive
                            ? (isAm
                                  ? NabeehColors.yellow
                                  : NabeehColors.darkBlue)
                            : NabeehColors.slate300,
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: isActive,
                activeColor: NabeehColors.background,
                activeTrackColor: const Color(0xFF181059),
                inactiveThumbColor: NabeehColors.slate400,
                inactiveTrackColor: NabeehColors.slate200,
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                onChanged: (val) {
                  _toggleReminderStatus(reminderId, isActive);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Days chip row
          if (daysText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? NabeehColors.lightBlue.withOpacity(0.05)
                      : NabeehColors.slate100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.bellRing,
                      size: 13,
                      color: isActive
                          ? NabeehColors.lightBlue
                          : NabeehColors.slate500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      daysText,
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? const Color(0xFF181059)
                            : NabeehColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Edit & Delete rectangle buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _editAlarm(reminderId, alarm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: NabeehColors.darkBlue,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.edit2,
                          size: 16,
                          color: NabeehColors.darkBlue,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'تعديل',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: NabeehColors.darkBlue,
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
                  onTap: () => _confirmDelete(reminderId),
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

  Widget _buildAddButton() {
    return Container(
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddReminderScreen()),
          );
        },
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text(
          'إضافة منبه جديد',
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            color: Colors.white,
            letterSpacing: 2,
            fontSize: 18,
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
    );
  }
}
