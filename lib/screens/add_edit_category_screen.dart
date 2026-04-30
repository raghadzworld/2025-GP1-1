import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../features/categories/data/models/category_model.dart';
import '../features/categories/data/models/sound_setting_model.dart';
import '../features/categories/data/services/category_service.dart';
import '../widgets/custom_widgets.dart';
import 'nabeeh_colors.dart';

class AddEditCategoryScreen extends StatefulWidget {
  final CategoryModel? category;
  final CategoryService? service;
  final List<CategoryModel> existingCategories;

  const AddEditCategoryScreen({
    super.key,
    this.category,
    this.service,
    this.existingCategories = const [],
  });

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  late final CategoryService _service;
  late TextEditingController _nameController;
  late List<SoundSettingModel> _sounds;
  bool _isSaving = false;
  String? _nameError;

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
    final trimmedName = _nameController.text.trim();

    if (trimmedName.isEmpty) {
      setState(() => _nameError = 'الرجاء إدخال اسم المجموعة');
      return;
    }

    final isDuplicate = widget.existingCategories.any((c) =>
        c.name.trim().toLowerCase() == trimmedName.toLowerCase() &&
        c.id != widget.category?.id);

    if (isDuplicate) {
      setState(() => _nameError = 'يوجد مجموعة بهذا الاسم، اختر اسماً مختلفاً');
      return;
    }

    setState(() {
      _nameError = null;
      _isSaving = true;
    });

    final cat = widget.category;
    final model = CategoryModel(
      id: cat?.id ?? '',
      name: trimmedName,
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
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.red, size: 24),
              ),
              const SizedBox(height: 16),
              const Text(
                'حذف المجموعة',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: NabeehColors.dark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'هل أنت متأكد؟ لا يمكن التراجع عن هذا الإجراء.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 13,
                  color: NabeehColors.slate400,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: NabeehColors.slate100),
                        ),
                      ),
                      child: const Text(
                        'إلغاء',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontWeight: FontWeight.w900,
                          color: NabeehColors.slate400,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'حذف',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final id = widget.category!.id;
      final activatedId = await _service.deleteCategory(
        id,
        currentCategories: widget.existingCategories,
      );
      if (mounted) Navigator.pop(context, DeletedCategoryResult(id, activatedId: activatedId));
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
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 24, right: 24, left: 24),
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
          Expanded(
            child: Text(
              isEditing ? 'تعديل الفئة' : 'إضافة فئة',
              style: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF181059),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF181059), Color(0xFF181059), Color(0xFF1773CF)],
                  stops: [0.09, 0.30, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
              ),
              child: const Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
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
          textDirection: TextDirection.rtl,
          keyboardType: TextInputType.text,
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
          decoration: InputDecoration(
            hintText: 'مثلاً: المنزل، العمل...',
            hintTextDirection: TextDirection.rtl,
            filled: true,
            fillColor: _nameError != null
                ? Colors.red.withValues(alpha: 0.05)
                : NabeehColors.slate50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: _nameError != null
                  ? BorderSide(color: Colors.red.withValues(alpha: 0.4))
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: _nameError != null
                    ? Colors.red.withValues(alpha: 0.6)
                    : NabeehColors.darkBlue.withValues(alpha: 0.4),
              ),
            ),
          ),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        if (_nameError != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertCircle,
                    size: 14, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  _nameError!,
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
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

class DeletedCategoryResult {
  final String id;
  final String? activatedId;
  const DeletedCategoryResult(this.id, {this.activatedId});
}
