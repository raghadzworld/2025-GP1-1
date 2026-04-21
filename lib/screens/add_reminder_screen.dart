import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'nabeeh_colors.dart';

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  // Custom Time Picker State
  late int selectedHour;
  late int selectedMinute;
  late bool isAm;
  
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _amPmController;

  String label = "منبه جديد";
  String repeat = "مطلقاً";
  double vibrationPowerValue = 1.0;
  String vibrationPattern = "متصل";

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedHour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    selectedMinute = now.minute;
    isAm = now.hour < 12;

    _hourController = FixedExtentScrollController(initialItem: selectedHour - 1);
    _minuteController = FixedExtentScrollController(initialItem: selectedMinute);
    _amPmController = FixedExtentScrollController(initialItem: isAm ? 0 : 1);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _amPmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: NabeehColors.background,
        body: Stack(
          children: [
            // Background gradient matching reminders_screen.dart
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCustomTimePicker(), 
                          const SizedBox(height: 32),
                          // Removed section titles here
                          _buildSettingCard(
                            icon: LucideIcons.calendarDays,
                            title: 'التكرار',
                            value: repeat,
                            onTap: _showRepeatPicker,
                          ),
                          const SizedBox(height: 12), 
                          _buildSettingCard(
                            icon: LucideIcons.tag,
                            title: 'التسمية',
                            value: label,
                            onTap: _showLabelDialog,
                          ),
                          const SizedBox(height: 12), 
                          _buildSettingCard(
                            icon: LucideIcons.activity,
                            title: 'نمط الاهتزاز',
                            value: vibrationPattern,
                            onTap: () {
                              _showOptionsSheet(
                                'نمط الاهتزاز',
                                ['متصل', 'نبضات', 'متقطع', 'تصاعدي'],
                                vibrationPattern,
                                (val) => setState(() => vibrationPattern = val),
                              );
                            },
                          ),
                          const SizedBox(height: 12), 
                          _buildSliderCard(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomActions(),
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
                border: Border.all(
                  color: NabeehColors.dark, 
                  width: 1.5,
                ),
              ),
              child: const Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: NabeehColors.dark, 
                  size: 18, 
                ),
              ),
            ),
          ),
          const Column(
            children: [
              Text(
                'تخصيص الوقت',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.slate400,
                  letterSpacing: 2,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
              Text(
                'إضافة منبه',
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
              border: Border.all(
                color: NabeehColors.background.withValues(alpha: 0.25),
                width: 1.5,
              ),
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

  Widget _buildCustomTimePicker() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: NabeehColors.slate50,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: NabeehColors.slate100),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: NabeehColors.dark.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 👇 Minutes Wheel 
              SizedBox(
                width: 80,
                child: ListWheelScrollView.useDelegate(
                  controller: _minuteController,
                  itemExtent: 64,
                  perspective: 0.005,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) => setState(() => selectedMinute = index),
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 60,
                    builder: (context, index) {
                      final isSelected = index == selectedMinute;
                      return Center(
                        child: Text(
                          index.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: isSelected ? 40 : 30,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            color: isSelected ? NabeehColors.darkBlue : NabeehColors.slate300,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const Text(
                ':',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.slate400,
                  height: 0.8,
                ),
              ),
              // 👇 Hours Wheel 
              SizedBox(
                width: 80,
                child: ListWheelScrollView.useDelegate(
                  controller: _hourController,
                  itemExtent: 64,
                  perspective: 0.005,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) => setState(() => selectedHour = index + 1),
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 12,
                    builder: (context, index) {
                      final val = index + 1;
                      final isSelected = val == selectedHour;
                      return Center(
                        child: Text(
                          val.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: isSelected ? 40 : 30,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            color: isSelected ? NabeehColors.darkBlue : NabeehColors.slate300,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // AM/PM Wheel with Icons 
              SizedBox(
                width: 70,
                child: ListWheelScrollView.useDelegate(
                  controller: _amPmController,
                  itemExtent: 64,
                  perspective: 0.005,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) => setState(() => isAm = index == 0),
                  childDelegate: ListWheelChildListDelegate(
                    children: [
                      Center(
                        child: Icon(
                          LucideIcons.sun,
                          size: isAm ? 32 : 24,
                          color: isAm ? NabeehColors.yellow : NabeehColors.slate300,
                        ),
                      ),
                      Center(
                        child: Icon(
                          LucideIcons.moon,
                          size: !isAm ? 32 : 24,
                          color: !isAm ? NabeehColors.darkBlue : NabeehColors.slate300,
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
  }

  Widget _buildSettingCard({required IconData icon, required String title, required String value, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: NabeehColors.slate50,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: NabeehColors.slate100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: NabeehColors.slate400, size: 20),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: NabeehColors.dark,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: NabeehColors.darkBlue, 
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_ios_rounded, color: NabeehColors.slate300, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: NabeehColors.slate50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NabeehColors.slate100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.zap, color: NabeehColors.slate400, size: 20),
              SizedBox(width: 16),
              Text(
                'قوة الاهتزاز',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('خفيف', style: TextStyle(fontFamily: 'IBMPlexSansArabic', color: NabeehColors.slate400, fontSize: 12, fontWeight: FontWeight.w900)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: NabeehColors.darkBlue, 
                    inactiveTrackColor: NabeehColors.slate200,
                    thumbColor: NabeehColors.background,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                    overlayColor: NabeehColors.darkBlue.withValues(alpha: 0.2), 
                  ),
                  child: Slider(
                    value: vibrationPowerValue,
                    min: 0,
                    max: 2,
                    divisions: 2,
                    onChanged: (val) => setState(() => vibrationPowerValue = val),
                  ),
                ),
              ),
              const Text('قوي', style: TextStyle(fontFamily: 'IBMPlexSansArabic', color: NabeehColors.slate400, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  void _showRepeatPicker() {
    final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    List<String> selected = repeat == "مطلقاً" ? [] : repeat.split('، ');

    showModalBottomSheet(
      context: context,
      backgroundColor: NabeehColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('التكرار', style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 20, fontWeight: FontWeight.w900, color: NabeehColors.dark)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: days.length,
                      itemBuilder: (context, index) {
                        final day = days[index];
                        final isSelected = selected.contains(day);
                        return CheckboxListTile(
                          title: Text(day, style: const TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.w600, color: NabeehColors.dark)),
                          value: isSelected,
                          activeColor: NabeehColors.darkBlue, 
                          side: const BorderSide(color: NabeehColors.slate300, width: 2),
                          checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          onChanged: (bool? val) {
                            setSheetState(() {
                              if (val == true) {
                                selected.add(day);
                              } else {
                                selected.remove(day);
                              }
                            });
                            setState(() {
                              if (selected.isEmpty) {
                                repeat = "مطلقاً";
                              } else if (selected.length == 7) {
                                repeat = "كل يوم";
                              } else {
                                repeat = selected.join('، ');
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showLabelDialog() {
    TextEditingController controller = TextEditingController(text: label);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: NabeehColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('التسمية', style: TextStyle(fontFamily: 'IBMPlexSansArabic', color: NabeehColors.dark, fontWeight: FontWeight.w900)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: NabeehColors.slate50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: NabeehColors.darkBlue, width: 1.5)),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 52), // ENFORCED IDENTICAL HEIGHT
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: NabeehColors.slate200, width: 1.5),
                      ),
                    ),
                    child: const Text('إلغاء', style: TextStyle(fontFamily: 'IBMPlexSansArabic', color: NabeehColors.slate500, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => label = controller.text);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NabeehColors.dark, 
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52), // ENFORCED IDENTICAL HEIGHT
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('حفظ', style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsSheet(String title, List<String> options, String currentValue, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NabeehColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(title, style: const TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 20, fontWeight: FontWeight.w900, color: NabeehColors.dark)),
              ),
              ...options.map((opt) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                title: Text(opt, style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontWeight: FontWeight.w600, color: opt == currentValue ? NabeehColors.darkBlue : NabeehColors.dark)),
                trailing: opt == currentValue ? const Icon(LucideIcons.checkCircle2, color: NabeehColors.darkBlue) : null,
                onTap: () {
                  onSelect(opt);
                  Navigator.pop(context);
                },
              )),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: NabeehColors.background,
        border: Border(top: BorderSide(color: NabeehColors.slate100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'إلغاء',
                style: TextStyle(
                  color: NabeehColors.slate400,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontFamily: 'IBMPlexSansArabic',
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: NabeehColors.dark,
                foregroundColor: NabeehColors.background,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'إضافة المنبه',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}