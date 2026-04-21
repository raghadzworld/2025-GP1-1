import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'add_reminder_screen.dart';
import 'nabeeh_colors.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Map<String, dynamic>> alarms = [
    {
      'time': '07:00',
      'period': 'ص',
      'label': 'الدواء الصباحي',
      'isActive': true,
      'days': 'كل يوم',
    },
    {
      'time': '08:30',
      'period': 'م',
      'label': 'تمرين',
      'isActive': false,
      'days': 'الاثنين، الأربعاء',
    },
  ];

@override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NabeehColors.background,
        body: Stack(
          children: [
            // 👇 Background gradient
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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          ...alarms.asMap().entries.map((entry) {
                            final index = entry.key;
                            final alarm = entry.value;
                            return _buildAlarmCard(alarm, index);
                          }),
                          const SizedBox(height: 8),
                          _buildAddButton(),
                          const SizedBox(height: 40),
                        ],
                      ),
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

  Widget _buildAlarmCard(Map<String, dynamic> alarm, int index) {
    final bool isActive = alarm['isActive'];
    final bool isAm = alarm['period'] == 'ص';

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
                    alarm['time'],
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
                  setState(() {
                    alarms[index]['isActive'] = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
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
                Text(
                  '${alarm['label']} • ${alarm['days']}',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isActive ? NabeehColors.lightBlue : NabeehColors.slate500,
                  ),
                ),
              ],
            ),
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
            const SizedBox(width: 8),
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