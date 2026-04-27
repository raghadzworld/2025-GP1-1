import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../features/categories/data/models/category_model.dart';
import '../features/categories/data/models/sound_setting_model.dart';
import '../features/categories/data/services/category_service.dart';
import '../widgets/custom_widgets.dart';
import 'nabeeh_colors.dart';

class AddEditCategoryScreen extends StatefulWidget {
  // يستقبل CategoryModel مباشرة بدلاً من Map
  final CategoryModel? category;
  final CategoryService? service;

  const AddEditCategoryScreen({super.key, this.category, this.service});

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  late final CategoryService _service;
  late TextEditingController _nameController;
  late List<SoundSettingModel> _sounds;
  bool _isSaving = false;

  static const List<int> _patternOptions = [1, 2, 3];

  // مصدر واحد للأصوات — عند إنشاء فئة جديدة يُغلق كل شيء عدا fire_alarm
  static List<SoundSettingModel> get _newCategoryDefaults =>
      CategoryService.defaultSounds
          .map((s) => s.copyWith(isEnabled: s.soundId == 'fire_alarm'))
          .toList();

  bool get isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CategoryService.withDefaults();
    _loadData();
  }

  void _loadData() {
    final cat = widget.category;
    if (cat != null) {
      _nameController = TextEditingController(text: cat.name);
      final soundMap = {for (final s in cat.sounds) s.soundId: s};
      _sounds = _newCategoryDefaults.map((def) {
        return soundMap[def.soundId] ??
            def.copyWith(isEnabled: def.soundId == 'fire_alarm');
      }).toList();
    } else {
      _nameController = TextEditingController();
      _sounds = List.from(_newCategoryDefaults);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء إدخال اسم الفئة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);

    final cat = widget.category;
    final model = CategoryModel(
      id: cat?.id ?? '',
      name: _nameController.text.trim(),
      isEnabled: cat?.isEnabled ?? false,
      sounds: _sounds,
    );

    try {
      CategoryModel saved;
      if (isEditing) {
        await _service.editCategory(model);
        // عند التعديل: أرجع النموذج المحدّث (fire_alarm مُطبَّق عليه)
        saved = model.copyWith(
          sounds: _service.enforceFireAlarm(model.sounds),
        );
      } else {
        saved = await _service.addCategory(model);
      }
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('حذف الفئة'),
          content: const Text(
            'هل أنت متأكد من حذف هذه الفئة؟ لا يمكن التراجع عن هذا الإجراء.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: NabeehColors.slate400)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final id = widget.category!.id;
      await _service.deleteCategory(id);
      if (mounted) Navigator.pop(context, DeletedCategoryResult(id));
    } on StateError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن حذف الفئة الوحيدة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPatternSheet(int soundIndex) {
    final current = _sounds[soundIndex].vibrationPattern;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'نمط الاهتزاز',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.dark,
                ),
              ),
            ),
            ..._patternOptions.map(
              (opt) => ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 32),
                title: Text(
                  _intensityLabel(opt),
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontWeight: FontWeight.w600,
                    color: opt == current
                        ? NabeehColors.darkBlue
                        : NabeehColors.dark,
                  ),
                ),
                trailing: opt == current
                    ? const Icon(LucideIcons.checkCircle2,
                        color: NabeehColors.darkBlue)
                    : null,
                onTap: () {
                  setState(() {
                    _sounds[soundIndex] =
                        _sounds[soundIndex].copyWith(vibrationPattern: opt);
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
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
                      const SizedBox(height: 32),
                      _buildSoundsSection(),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.only(top: 52, bottom: 20, right: 20, left: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB8D4F0), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: NabeehColors.dark, width: 1.5),
              ),
              child: const Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(Icons.arrow_forward_ios_rounded,
                    color: NabeehColors.dark, size: 18),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                isEditing ? 'تعديل الفئة' : 'إضافة فئة',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.dark,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF181059),
                  Color(0xFF181059),
                  Color(0xFF1773CF)
                ],
                stops: [0.09, 0.30, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25), width: 1.5),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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

  Widget _buildSoundsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الأصوات والاهتزاز',
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
          itemCount: _sounds.length,
          itemBuilder: (_, i) => _buildSoundItem(i),
        ),
      ],
    );
  }

  Widget _buildSoundItem(int index) {
    final sound = _sounds[index];
    final isFireAlarm = sound.soundId == 'fire_alarm';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            sound.isEnabled ? const Color(0xFFEFF6FF) : NabeehColors.slate50,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: sound.isEnabled
              ? const Color(0xFFDBEAFE)
              : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (isFireAlarm) ...[
                const Icon(Icons.lock_outline_rounded,
                    size: 14, color: NabeehColors.slate300),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  sound.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: sound.isEnabled
                        ? NabeehColors.dark
                        : NabeehColors.slate400,
                  ),
                ),
              ),
              Switch(
                value: sound.isEnabled,
                onChanged: isFireAlarm
                    ? null
                    : (val) => setState(
                        () => _sounds[index] = sound.copyWith(isEnabled: val)),
                activeThumbColor: NabeehColors.accent,
                inactiveThumbColor: NabeehColors.slate300,
                inactiveTrackColor: NabeehColors.slate100,
              ),
            ],
          ),
          if (sound.isEnabled) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFDBEAFE)),
            const SizedBox(height: 12),
            _buildVibrationSlider(index),
            const SizedBox(height: 12),
            _buildPatternPicker(index),
          ],
        ],
      ),
    );
  }

  Widget _buildVibrationSlider(int soundIndex) {
    final sound = _sounds[soundIndex];
    final currentValue = sound.vibrationPower.toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
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
              Icon(LucideIcons.zap, color: NabeehColors.slate400, size: 18),
              SizedBox(width: 12),
              Text(
                'قوة الاهتزاز',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.dark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'خفيف',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: NabeehColors.slate400,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: NabeehColors.darkBlue,
                    inactiveTrackColor: NabeehColors.slate200,
                    thumbColor: Colors.white,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 12),
                    overlayColor:
                        NabeehColors.darkBlue.withValues(alpha: 0.15),
                  ),
                  child: Slider(
                    value: currentValue,
                    min: 1,
                    max: 3,
                    divisions: 2,
                    onChanged: (val) => setState(() {
                      _sounds[soundIndex] =
                          sound.copyWith(vibrationPower: val.round());
                    }),
                  ),
                ),
              ),
              const Text(
                'قوي',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  color: NabeehColors.slate400,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatternPicker(int soundIndex) {
    final sound = _sounds[soundIndex];
    return GestureDetector(
      onTap: () => _showPatternSheet(soundIndex),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                const Icon(LucideIcons.activity,
                    color: NabeehColors.slate400, size: 18),
                const SizedBox(width: 12),
                const Text(
                  'نمط الاهتزاز',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: NabeehColors.dark,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  _intensityLabel(sound.vibrationPattern),
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: NabeehColors.darkBlue,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: NabeehColors.slate300, size: 13),
              ],
            ),
          ],
        ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
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
                  onClick: () {
                    if (!_isSaving) _handleSave();
                  },
                ),
              ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _isSaving ? null : _handleDelete,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.red.withValues(alpha: 0.3)),
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

  String _intensityLabel(int value) {
    switch (value) {
      case 1:
        return 'خفيف';
      case 2:
        return 'متوسط';
      case 3:
        return 'قوي';
      default:
        return '$value';
    }
  }
}

// نتيجة الحذف تحمل الـ id للحذف من القائمة المحلية
class DeletedCategoryResult {
  final String id;
  const DeletedCategoryResult(this.id);
}
