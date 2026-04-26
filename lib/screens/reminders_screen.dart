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
          .collection('User') // Using exact User collection
          .doc(currentUser!.uid)
          .collection('Reminders')
          .doc(reminderId)
          .delete();
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المنبه بنجاح', style: TextStyle(fontFamily: 'IBMPlexSansArabic'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الحذف: $e', style: const TextStyle(fontFamily: 'IBMPlexSansArabic'))),
        );
      }
    }
  }

  Future<void> _toggleReminderStatus(String reminderId, bool currentStatus) async {
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(LucideIcons.alertTriangle, color: Colors.red),
                SizedBox(width: 10),
                Text(
                  'حذف المنبه',
                  style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
            content: const Text(
              'هل أنت متأكد من رغبتك في حذف هذا المنبه؟',
              style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 16),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        fixedSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic', 
                          color: NabeehColors.slate500, 
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); 
                        _deleteReminder(reminderId); 
                      },
                      style: ElevatedButton.styleFrom(
                        fixedSize: const Size.fromHeight(50),
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'حذف',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic', 
                          fontWeight: FontWeight.bold, 
                          color: Colors.white,
                          fontSize: 16,
                        ),
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
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NabeehColors.background,
        body: Stack(
          children: [
            Container(
              height: 250,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFB8D4F0), Colors.white],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 40),
                  
                  Expanded(
                    child: currentUser == null
                        ? const Center(child: Text('الرجاء تسجيل الدخول لعرض المنبهات', style: TextStyle(fontFamily: 'IBMPlexSansArabic')))
                        : StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('User')
                                .doc(currentUser!.uid)
                                .collection('Reminders') 
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: NabeehColors.darkBlue));
                              }

                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return _buildEmptyState();
                              }

                              final reminders = snapshot.data!.docs;

                              return SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(
                                  children: [
                                    ...reminders.map((doc) {
                                      final data = doc.data() as Map<String, dynamic>;
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
          ],
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
            style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 18, color: NabeehColors.slate500, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: NabeehColors.background,
                border: Border.all(color: NabeehColors.dark, width: 1.5),
              ),
              child: const Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(Icons.arrow_forward_ios_rounded, color: NabeehColors.dark, size: 18),
              ),
            ),
          ),
          const Column(
            children: [
              Text(
                'إدارة أوقاتك',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.slate400,
                  letterSpacing: 2,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
              Text(
                'المنبهات',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.dark,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [NabeehColors.darkNavy, NabeehColors.darkNavy, NabeehColors.lightBlue],
                stops: [0.09, 0.30, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                'assets/images/icon_signLan.png',
                color: NabeehColors.background,
                colorBlendMode: BlendMode.srcIn,
                fit: BoxFit.contain,
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
    final String daysText = daysArray.isEmpty ? 'مرة واحدة' : daysArray.join('، ');

    // 👇 FIXED: Much simpler and 100% accurate AM/PM check
    final bool isAm = timeString.contains('ص');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isActive ? NabeehColors.background : NabeehColors.slate50,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isActive ? NabeehColors.lightBlue : NabeehColors.slate100,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: NabeehColors.lightBlue.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    timeString.replaceAll('ص', '').replaceAll('م', '').trim(), 
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: isActive ? NabeehColors.darkBlue : NabeehColors.slate400,
                      letterSpacing: -2,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    isAm ? LucideIcons.sun : LucideIcons.moon,
                    size: 28,
                    color: isActive ? (isAm ? NabeehColors.yellow : NabeehColors.darkBlue) : NabeehColors.slate300,
                  ),
                ],
              ),
              Switch(
                value: isActive,
                activeColor: NabeehColors.background,
                activeTrackColor: NabeehColors.lightBlue,
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
          
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? NabeehColors.lightBlue.withOpacity(0.05) : NabeehColors.slate100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.bellRing, size: 14, color: isActive ? NabeehColors.lightBlue : NabeehColors.slate500),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$label • $daysText',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isActive ? NabeehColors.lightBlue : NabeehColors.slate500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              GestureDetector(
                onTap: () => _editAlarm(reminderId, alarm),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: NabeehColors.slate100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.edit2, size: 18, color: NabeehColors.slate500),
                ),
              ),
              const SizedBox(width: 8),
              
              GestureDetector(
                onTap: () => _confirmDelete(reminderId),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.trash2, size: 18, color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AddReminderScreen()));
      },
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: NabeehColors.darkBlue, width: 2),
          borderRadius: BorderRadius.circular(32),
          color: Colors.transparent,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.plus, color: NabeehColors.darkBlue),
            SizedBox(width: 8),
            Text(
              'إضافة منبه جديد',
              style: TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                color: NabeehColors.darkBlue,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}