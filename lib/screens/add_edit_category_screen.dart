import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/custom_widgets.dart';
import 'Nabeeh_Colors.dart';

class AddEditCategoryScreen extends StatefulWidget {
  final Map<String, dynamic>? category;

  const AddEditCategoryScreen({super.key, this.category});

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  String selectedIcon = 'Home';
  List<Map<String, dynamic>> selectedSounds = [];

  final List<Map<String, dynamic>> availableIcons = [
    {'name': 'Home', 'icon': LucideIcons.home},
    {'name': 'Work', 'icon': LucideIcons.briefcase},
    {'name': 'Outdoor', 'icon': LucideIcons.trees},
    {'name': 'Travel', 'icon': LucideIcons.car},
    {'name': 'Explore', 'icon': LucideIcons.compass},
    {'name': 'School', 'icon': LucideIcons.graduationCap},
  ];

  final List<String> availableSounds = [
    'الآذان',
    'إنذار الحريق',
    'بكاء طفل',
    'طرق على الباب',
    'بوق سيارة'
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
      selectedIcon = cat['iconName'] ?? 'Home';
      
      // Deep copy the sounds list with vibration levels
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
      selectedIcon = 'Home';
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
        'iconName': selectedIcon,
        'sounds': selectedSounds,
      });
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('حذف الفئة', textDirection: TextDirection.rtl),
        content: const Text(
          'هل أنت متأكد من حذف هذه الفئة؟ لا يمكن التراجع عن هذا الإجراء.',
          textDirection: TextDirection.rtl,
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
    );

    if (confirm == true) {
      Navigator.pop(context, 'DELETE');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 64),
          _buildHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNameInput(),
                  const SizedBox(height: 24),
                  _buildDescriptionInput(),
                  const SizedBox(height: 32),
                  _buildIconSelection(),
                  const SizedBox(height: 40),
                  _buildSoundsSelection(),
                ],
              ),
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تخصيص الفئة',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.slate400,
                  letterSpacing: 2,
                ),
              ),
              Text(
                isEditing ? 'تعديل الفئة' : 'إضافة فئة',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.dark,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: NabeehColors.slate100),
              ),
              child: const Icon(LucideIcons.arrowLeft, color: NabeehColors.slate400),
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

  Widget _buildIconSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اختر أيقونة',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: NabeehColors.slate400,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: availableIcons.length,
          itemBuilder: (context, index) {
            final item = availableIcons[index];
            final isSelected = item['name'] == selectedIcon;
            return GestureDetector(
              onTap: () => setState(() => selectedIcon = item['name']),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? NabeehColors.accent : NabeehColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: NabeehColors.accent.withValues(alpha: 0.4),
                            blurRadius: 20,
                          )
                        ]
                      : null,
                ),
                child: Icon(
                  item['icon'],
                  color: isSelected ? NabeehColors.dark : NabeehColors.slate300,
                  size: 24,
                ),
              ),
            );
          },
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
    // Fix: In RTL, "قوي" should be on the left, "ضعيف" on the right visually
    // We'll keep the logical order left-to-right as weak to strong,
    // but visually we reverse the display order for RTL.
    final displayLevels = levels.reversed.toList(); // ['قوي', 'متوسط', 'ضعيف']
    final currentIndex = levels.indexOf(currentLevel);
    // Map logical index (0=weak,1=medium,2=strong) to visual position (0=right,1=center,2=left)
    final visualIndex = 2 - currentIndex; // Because strong should be on left

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
                    // Base line
                    Container(
                      height: 2,
                      color: NabeehColors.slate100,
                      margin: EdgeInsets.symmetric(horizontal: constraints.maxWidth / 6),
                    ),
                    // Ticks at positions: left (strong), center (medium), right (weak)
                    ...displayLevels.asMap().entries.map((entry) {
                      final idx = entry.key;
                      double leftPosition;
                      if (idx == 0) {
                        leftPosition = 0; // Left (strong)
                      } else if (idx == 1) {
                        leftPosition = constraints.maxWidth / 2 - 1; // Center (medium)
                      } else {
                        leftPosition = constraints.maxWidth - 2; // Right (weak)
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
                    // Thumb positioned based on visual index
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      left: visualIndex == 0
                          ? 0 // Strong (left)
                          : visualIndex == 1
                              ? constraints.maxWidth / 2 - 16 // Medium (center)
                              : constraints.maxWidth - 32, // Weak (right)
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
                    // Tap areas mapped to logical levels
                    Row(
                      children: displayLevels.map((displayLevel) {
                        // displayLevel order: 'قوي', 'متوسط', 'ضعيف'
                        // We need to map tap to the logical level
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
          // Labels under ruler (display order: strong on left, weak on right)
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
      padding: const EdgeInsets.all(32),
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