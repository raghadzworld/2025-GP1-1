import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  DateTime selectedTime = DateTime.now();
  String label = "منبه";
  String repeat = "مطلقاً";
  double vibrationPowerValue = 1.0;
  String vibrationPattern = "متصل";

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7), // iOS grouped background color
        appBar: AppBar(
          backgroundColor: const Color(0xFFF2F2F7),
          elevation: 0,
          title: Text(
            'إضافة منبه',
            style: GoogleFonts.notoSansArabic(
              color: const Color(0xFF1A1A40),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          leading: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.notoSansArabic(color: Colors.blue, fontSize: 16)),
          ),
          leadingWidth: 80,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Time Picker
              Container(
                height: 200,
                color: const Color(0xFFF2F2F7),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: selectedTime,
                  onDateTimeChanged: (DateTime newTime) {
                    setState(() {
                      selectedTime = newTime;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              
              // Settings List
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildSettingsRow(
                      title: 'التكرار',
                      value: repeat,
                      onTap: () {
                        _showRepeatPicker();
                      },
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildSettingsRow(
                      title: 'التسمية',
                      value: label,
                      onTap: () {
                        _showLabelDialog();
                      },
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildSliderRow(),
                    const Divider(height: 1, indent: 16),
                    _buildSettingsRow(
                      title: 'نمط الاهتزاز',
                      value: vibrationPattern,
                      onTap: () {
                        _showOptionsSheet('نمط الاهتزاز', ['متصل', 'نبضات', 'متقطع', 'تصاعدي'], vibrationPattern, (val) {
                          setState(() => vibrationPattern = val);
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSaveButton(),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsRow({required String title, required String value, required VoidCallback onTap}) {
    return ListTile(
      title: Text(title, style: GoogleFonts.notoSansArabic(fontSize: 16, color: const Color(0xFF1A1A40))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: GoogleFonts.notoSansArabic(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(width: 8),
          Icon(Icons.chevron_left, color: Colors.grey.shade400),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showRepeatPicker() {
    final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    List<String> selected = repeat == "مطلقاً" ? [] : repeat.split('، ');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('التكرار', style: GoogleFonts.notoSansArabic(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: days.length,
                    itemBuilder: (context, index) {
                      final day = days[index];
                      final isSelected = selected.contains(day);
                      return CheckboxListTile(
                        title: Text(day, style: GoogleFonts.notoSansArabic()),
                        value: isSelected,
                        activeColor: Colors.blue,
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
      builder: (context) => AlertDialog(
        title: Text('التسمية', style: GoogleFonts.notoSansArabic()),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.notoSansArabic()),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                label = controller.text;
              });
              Navigator.pop(context);
            },
            child: Text('حفظ', style: GoogleFonts.notoSansArabic()),
          ),
        ],
      ),
    );
  }

  void _showOptionsSheet(String title, List<String> options, String currentValue, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(title, style: GoogleFonts.notoSansArabic(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...options.map((opt) => ListTile(
              title: Text(opt, style: GoogleFonts.notoSansArabic()),
              trailing: opt == currentValue ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                onSelect(opt);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildSliderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('قوة الاهتزاز', style: GoogleFonts.notoSansArabic(fontSize: 16, color: const Color(0xFF1A1A40))),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('خفيف', style: GoogleFonts.notoSansArabic(color: Colors.grey.shade600, fontSize: 12)),
              Expanded(
                child: Slider(
                  value: vibrationPowerValue,
                  min: 0,
                  max: 2,
                  divisions: 2,
                  activeColor: Colors.blue,
                  onChanged: (val) {
                    setState(() {
                      vibrationPowerValue = val;
                    });
                  },
                ),
              ),
              Text('قوي', style: GoogleFonts.notoSansArabic(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.save, color: Colors.white),
      label: const Text(
        'حفظ المنبه',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A1A40),
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
