import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'nabeeh_colors.dart';

class AddReminderScreen extends StatefulWidget {
  final String? reminderId;
  final Map<String, dynamic>? existingData;

  const AddReminderScreen({super.key, this.reminderId, this.existingData});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  late int selectedHour;
  late int selectedMinute;
  late bool isAm;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _amPmController;

  String label = "منبه"; // 👈 Default label set to "منبه"
  String repeat = "مطلقاً";
  double vibrationPowerValue = 1.0;
  String vibrationPattern = "متصل";

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (widget.existingData != null) {
      final data = widget.existingData!;
      label = data['label'] ?? "منبه";

      List<dynamic> daysArray = data['daysActive'] ?? [];
      if (daysArray.isEmpty) {
        repeat = "مطلقاً";
      } else if (daysArray.length == 7) {
        repeat = "كل يوم";
      } else {
        repeat = daysArray.join('، ');
      }

      int vp = data['vibrationPower'] ?? 2;
      vibrationPowerValue = (vp - 1).clamp(0, 2).toDouble();

      int vpat = data['vibrationPattern'] ?? 1;
      List<String> patterns = ['متصل', 'نبضات', 'متقطع', 'تصاعدي'];
      vibrationPattern = (vpat >= 1 && vpat <= patterns.length)
          ? patterns[vpat - 1]
          : "متصل";

      String timeStr = data['time'] ?? "12:00 ص";
      isAm = timeStr.contains('ص');
      String cleanStr = timeStr.replaceAll('ص', '').replaceAll('م', '').trim();
      List<String> parts = cleanStr.split(':');
      selectedHour = int.tryParse(parts.isNotEmpty ? parts[0] : '12') ?? 12;
      selectedMinute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    } else {
      selectedHour = now.hour > 12
          ? now.hour - 12
          : (now.hour == 0 ? 12 : now.hour);
      selectedMinute = now.minute;
      isAm = now.hour < 12;
    }

    _hourController = FixedExtentScrollController(
      initialItem: selectedHour - 1,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: selectedMinute,
    );
    _amPmController = FixedExtentScrollController(initialItem: isAm ? 0 : 1);
  }

  Future<void> _saveReminder() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final timeString =
          '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')} ${isAm ? 'ص' : 'م'}';

      List<String> daysActive = [];
      if (repeat == "كل يوم") {
        daysActive = [
          'الأحد',
          'الاثنين',
          'الثلاثاء',
          'الأربعاء',
          'الخميس',
          'الجمعة',
          'السبت',
        ];
      } else if (repeat != "مطلقاً") {
        daysActive = repeat.split('، ');
      }

      int powerInt = vibrationPowerValue.toInt() + 1;
      int patternInt =
          ['متصل', 'نبضات', 'متقطع', 'تصاعدي'].indexOf(vibrationPattern) + 1;
      if (patternInt == 0) patternInt = 1;

      final reminderData = {
        'label': label,
        'time': timeString,
        'daysActive': daysActive,
        'isEnabled': widget.existingData?['isEnabled'] ?? true,
        'vibrationPower': powerInt,
        'vibrationPattern': patternInt,
      };

      final remindersRef = FirebaseFirestore.instance
          .collection('User')
          .doc(uid)
          .collection('Reminders');

      if (widget.reminderId == null) {
        await remindersRef.add(reminderData);
      } else {
        await remindersRef.doc(widget.reminderId).update(reminderData);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ: $e',
              style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        backgroundColor: Colors.white,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
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
              Text(
                widget.reminderId == null ? 'إضافة منبه' : 'تعديل منبه',
                style: const TextStyle(
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
                  color: Colors.white.withValues(alpha: 0.25),
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
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                child: ListWheelScrollView.useDelegate(
                  controller: _minuteController,
                  itemExtent: 64,
                  perspective: 0.005,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) =>
                      setState(() => selectedMinute = index),
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 60,
                    builder: (context, index) {
                      final isSelected = index == selectedMinute;
                      return Center(
                        child: Text(
                          index.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontSize: isSelected ? 28 : 20,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.bold,
                            color: isSelected
                                ? NabeehColors.darkBlue
                                : NabeehColors.slate300,
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
                  fontWeight: FontWeight.bold,
                  color: NabeehColors.slate400,
                  height: 0.8,
                ),
              ),
              SizedBox(
                width: 80,
                child: ListWheelScrollView.useDelegate(
                  controller: _hourController,
                  itemExtent: 64,
                  perspective: 0.005,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) =>
                      setState(() => selectedHour = index + 1),
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
                            fontSize: isSelected ? 28 : 20,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.bold,
                            color: isSelected
                                ? NabeehColors.darkBlue
                                : NabeehColors.slate300,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 70,
                child: ListWheelScrollView.useDelegate(
                  controller: _amPmController,
                  itemExtent: 64,
                  perspective: 0.005,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) =>
                      setState(() => isAm = index == 0),
                  childDelegate: ListWheelChildListDelegate(
                    children: [
                      Center(
                        child: Icon(
                          LucideIcons.sun,
                          size: isAm ? 32 : 24,
                          color: isAm
                              ? NabeehColors.yellow
                              : NabeehColors.slate300,
                        ),
                      ),
                      Center(
                        child: Icon(
                          LucideIcons.moon,
                          size: !isAm ? 32 : 24,
                          color: !isAm
                              ? NabeehColors.darkBlue
                              : NabeehColors.slate300,
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

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
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
                    fontWeight: FontWeight.bold,
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
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: NabeehColors.slate300,
                  size: 14,
                ),
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
                  fontWeight: FontWeight.bold,
                  color: NabeehColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'خفيف',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: NabeehColors.slate400,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: NabeehColors.darkBlue,
                    inactiveTrackColor: NabeehColors.slate200,
                    thumbColor: NabeehColors.background,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                    ),
                    overlayColor: NabeehColors.darkBlue.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: vibrationPowerValue,
                    min: 0,
                    max: 2,
                    divisions: 2,
                    onChanged: (val) =>
                        setState(() => vibrationPowerValue = val),
                  ),
                ),
              ),
              const Text(
                'قوي',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: NabeehColors.slate400,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRepeatPicker() {
    final days = [
      'الأحد',
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    List<String> selected = repeat == "مطلقاً" ? [] : repeat.split('، ');

    showModalBottomSheet(
      context: context,
      backgroundColor: NabeehColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'التكرار',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: NabeehColors.dark,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: days.length,
                      itemBuilder: (context, index) {
                        final day = days[index];
                        final isSelected = selected.contains(day);
                        return CheckboxListTile(
                          title: Text(
                            day,
                            style: const TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              fontWeight: FontWeight.w600,
                              color: NabeehColors.dark,
                            ),
                          ),
                          value: isSelected,
                          activeColor: NabeehColors.darkBlue,
                          side: const BorderSide(
                            color: NabeehColors.slate300,
                            width: 2,
                          ),
                          checkboxShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
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
          },
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'التسمية',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              color: NabeehColors.dark,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: NabeehColors.slate50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: NabeehColors.darkBlue,
                  width: 1.5,
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            Row(
              children: [
                // 1. SAVE BUTTON (Right Side in RTL)
                Expanded(
                  child: Container(
                    height: 52, // 👈 Strict height
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF181059), Color(0xFF1773CF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => label = controller.text);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.save, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'حفظ',
                            style: TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. CANCEL BUTTON (Left Side in RTL)
                Expanded(
                  child: Container(
                    height: 52, // 👈 Exact same strict height
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: NabeehColors.slate200,
                        width: 1.5,
                      ),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }

  void _showOptionsSheet(
    String title,
    List<String> options,
    String currentValue,
    Function(String) onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NabeehColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: NabeehColors.dark,
                  ),
                ),
              ),
              ...options.map(
                (opt) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                  title: Text(
                    opt,
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontWeight: FontWeight.w600,
                      color: opt == currentValue
                          ? NabeehColors.darkBlue
                          : NabeehColors.dark,
                    ),
                  ),
                  trailing: opt == currentValue
                      ? const Icon(
                          LucideIcons.checkCircle2,
                          color: NabeehColors.darkBlue,
                        )
                      : null,
                  onTap: () {
                    onSelect(opt);
                    Navigator.pop(context);
                  },
                ),
              ),
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
          // 1. Add/Update Reminder Button (Right Side in RTL)
          Expanded(
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
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
                onPressed: _isLoading ? null : _saveReminder,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            LucideIcons.save,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.reminderId == null
                                ? 'إضافة المنبه'
                                : 'تحديث المنبه',
                            style: const TextStyle(
                              fontFamily: 'IBMPlexSansArabic',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // 2. Cancel Button (Left Side in RTL)
          Expanded(
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color.fromARGB(255, 235, 233, 229),
                ),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.x, color: NabeehColors.slate500, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'إلغاء',
                      style: TextStyle(
                        color: NabeehColors.slate500,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
