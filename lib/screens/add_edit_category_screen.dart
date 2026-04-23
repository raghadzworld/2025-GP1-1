import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/custom_widgets.dart';
import 'nabeeh_colors.dart';

class AddEditCategoryScreen extends StatefulWidget {
  final Map<String, dynamic>? category;

  const AddEditCategoryScreen({super.key, this.category});

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  List<Map<String, dynamic>> selectedSounds = [];

  final List<String> availableSounds = [
    'الآذان',
    'إنذار الحريق',
    'بكاء طفل',
    'طرق على الباب',
    'جرس الباب '
  ];

  bool get isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _loadCategoryData();
  }

  void _loadCategoryData() {
    final cat = widget.category;
    if (cat != null) {
      _nameController = TextEditingController(text: cat['name'] ?? '');
      _descController = TextEditingController(text: cat['desc'] ?? '');
      if (cat['sounds'] != null) {
        selectedSounds = List<Map<String, dynamic>>.from(
          (cat['sounds'] as List).map((s) => Map<String, dynamic>.from(s))
        );
      } else {
        selectedSounds = [];
      }
    } else {
      _nameController = TextEditingController();
      _descController = TextEditingController();
      selectedSounds = [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool _validateAndSave() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال اسم الفئة'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    if (selectedSounds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء اختيار صوت واحد على الأقل'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
    return true;
  }

  void _handleSave() {
    if (_validateAndSave()) {
      Navigator.pop(context, {
        'name': _nameController.text.trim(),
        'desc': _descController.text.trim(),
        'sounds': selectedSounds,
      });
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('حذف الفئة'),
          content: const Text(
            'هل أنت متأكد من حذف هذه الفئة؟ لا يمكن التراجع عن هذا الإجراء.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: NabeehColors.slate400)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      Navigator.pop(context, 'DELETE');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildNameInput(),
                      const SizedBox(height: 24),
                      _buildDescriptionInput(),
                      const SizedBox(height: 40),
                      _buildSoundsSelection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  // ─── Custom Header matching EditProfileScreen / HomeScreen ─────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 52, bottom: 20, right: 20, left: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB8D4F0), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          // Right side: Back button (white circle, border)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
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

          // Center: Title – flexible
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                isEditing ? 'تعديل الفئة' : 'إضافة فئة',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.dark,
                  letterSpacing: -1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Left side: Blue gradient sign language icon
          Container(
            width: 50,
            height: 50,
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
              padding: const EdgeInsets.all(12),
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

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اسم الفئة',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: NabeehColors.slate400,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'مثلاً: المنزل، العمل...',
            filled: true,
            fillColor: NabeehColors.slate50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildDescriptionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'وصف الفئة',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: NabeehColors.slate400,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descController,
          decoration: InputDecoration(
            hintText: 'وصف قصير لهذه البيئة...',
            filled: true,
            fillColor: NabeehColors.slate50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
          maxLines: 2,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSoundsSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الأصوات وشِدّة الاهتزاز',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: NabeehColors.slate400,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: availableSounds.length,
          itemBuilder: (context, index) {
            final soundName = availableSounds[index];
            final soundIdx = selectedSounds.indexWhere((s) => s['name'] == soundName);
            final isSelected = soundIdx != -1;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEFF6FF) : NabeehColors.background,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isSelected ? const Color(0xFFDBEAFE) : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              selectedSounds.add({
                                'name': soundName,
                                'vibration': 'متوسط',
                              });
                            } else {
                              selectedSounds.removeAt(soundIdx);
                            }
                          });
                        },
                        activeColor: NabeehColors.accent,
                        side: const BorderSide(color: NabeehColors.slate300, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        soundName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? NabeehColors.dark : NabeehColors.slate400,
                        ),
                      ),
                    ],
                  ),
                  if (isSelected) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFDBEAFE)),
                    const SizedBox(height: 16),
                    _buildVibrationSelector(soundName, soundIdx),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVibrationSelector(String soundName, int soundIdx) {
    final levels = ['ضعيف', 'متوسط', 'قوي'];
    final currentLevel = selectedSounds[soundIdx]['vibration'];
    final displayLevels = levels.reversed.toList(); // ['قوي', 'متوسط', 'ضعيف']
    final currentIndex = levels.indexOf(currentLevel);
    final visualIndex = 2 - currentIndex;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NabeehColors.slate100),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.activity, size: 12, color: NabeehColors.accent),
                  const SizedBox(width: 8),
                  const Text(
                    'مستوى الاهتزاز',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: NabeehColors.slate400,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: NabeehColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  currentLevel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: NabeehColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 2,
                      color: NabeehColors.slate100,
                      margin: EdgeInsets.symmetric(horizontal: constraints.maxWidth / 6),
                    ),
                    ...displayLevels.asMap().entries.map((entry) {
                      final idx = entry.key;
                      double leftPosition;
                      if (idx == 0) {
                        leftPosition = 0;
                      } else if (idx == 1) {
                        leftPosition = constraints.maxWidth / 2 - 1;
                      } else {
                        leftPosition = constraints.maxWidth - 2;
                      }
                      return Positioned(
                        left: leftPosition,
                        child: Container(
                          width: 2,
                          height: idx == 1 ? 16 : 12,
                          color: NabeehColors.slate200,
                        ),
                      );
                    }),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      left: visualIndex == 0
                          ? 0
                          : visualIndex == 1
                              ? constraints.maxWidth / 2 - 16
                              : constraints.maxWidth - 32,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: NabeehColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: NabeehColors.accent.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            children: List.generate(
                              4,
                              (_) => Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: NabeehColors.dark,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: displayLevels.map((displayLevel) {
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              String logicalLevel;
                              if (displayLevel == 'قوي') {
                                logicalLevel = 'قوي';
                              } else if (displayLevel == 'متوسط') {
                                logicalLevel = 'متوسط';
                              } else {
                                logicalLevel = 'ضعيف';
                              }
                              setState(() {
                                selectedSounds[soundIdx]['vibration'] = logicalLevel;
                              });
                            },
                            behavior: HitTestBehavior.opaque,
                            child: const SizedBox.expand(),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: displayLevels.map((level) {
                final isSelected = level == currentLevel;
                return Text(
                  level,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? NabeehColors.dark : NabeehColors.slate300,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: NabeehColors.background,
        border: Border(top: BorderSide(color: NabeehColors.slate100)),
      ),
      child: Column(
        children: [
          Row(
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
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: PremiumButton(
                  text: isEditing ? 'تحديث الفئة' : 'إضافة الفئة',
                  color: NabeehColors.dark,
                  textColor: Colors.white,
                  onClick: _handleSave,
                ),
              ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _handleDelete,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Text(
                    'حذف الفئة',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
