import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_reminder_screen.dart';
import 'listening_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  // Dummy data
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
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'المنبهات',
                          style: GoogleFonts.notoSansArabic(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A40),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.blue, size: 32),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AddReminderScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(thickness: 1, color: Color(0xFFEEEEEE)),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 10, bottom: 120),
                      itemCount: alarms.length,
                      separatorBuilder: (context, index) => const Divider(
                        thickness: 1,
                        color: Color(0xFFEEEEEE),
                        indent: 20,
                        endIndent: 20,
                      ),
                      itemBuilder: (context, index) {
                        final alarm = alarms[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        alarm['time'],
                                        style: GoogleFonts.notoSansArabic(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w300,
                                          color: alarm['isActive'] ? const Color(0xFF1A1A40) : Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        alarm['period'],
                                        style: GoogleFonts.notoSansArabic(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                          color: alarm['isActive'] ? const Color(0xFF1A1A40) : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${alarm['label']}، ${alarm['days']}',
                                    style: GoogleFonts.notoSansArabic(
                                      fontSize: 14,
                                      color: alarm['isActive'] ? Colors.grey.shade700 : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: alarm['isActive'],
                                activeThumbColor: Colors.blue,
                                onChanged: (val) {
                                  setState(() {
                                    alarms[index]['isActive'] = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            _buildBottomNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Positioned(
      bottom: 30,
      left: 20,
      right: 20,
      child: Container(
        height: 75,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(37.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20), // 0.08 opacity
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            // 4. Home Icon (Active state)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/home.png',
                    width: 20,
                    height: 20,
                    color: Colors.blue,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'الرئيسية',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            
            // 3. Watch/Bracelet Icon
            IconButton(
              onPressed: () {},
              icon: Image.asset('assets/images/bracelet.png', width: 24, height: 24),
            ),
            const Spacer(),
            
            // 2. SOS Icon
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ListeningScreen()),
                );
              },
              icon: Image.asset('assets/images/sos.png', width: 24, height: 24),
            ),
            const Spacer(),
            
            // 1. Profile Icon (Inactive state)
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.person_outline, color: Colors.grey, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}
