import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../features/categories/data/models/category_model.dart';
import '../features/categories/data/models/location_trigger_model.dart';
import '../features/categories/data/models/sound_setting_model.dart';
import '../features/categories/data/services/category_service.dart';
import '../services/listening_background_service.dart';
import '../services/sign_language_mode.dart';
import '../widgets/sign_video_card.dart';
import 'location_picker_screen.dart';
import 'nabeeh_colors.dart';

/// فيديو لغة الإشارة لهذي الصفحة — غيّر الاسم لاسم ملفك
const String _kSignVideoAsset = 'assets/videos/sign_add_edit_category.mp4';

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
  LocationTriggerModel? _locationTrigger;
  bool _isSaving = false;
  String? _nameError;

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
      _locationTrigger = cat.locationTrigger;
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
      locationTrigger: _locationTrigger,
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
      unawaited(notifyListeningServiceCategoriesChanged());
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final keyboardOpen = keyboardHeight > 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // نتحكم بمساحة الكيبورد يدويًا (padding سفلي داخل الـ scroll)
        resizeToAvoidBottomInset: false,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFDDEEF8), Color(0xFFF2F9FE), Colors.white],
              stops: [0.0, 0.35, 0.6],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      keyboardHeight + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildSignVideoBox(),
                        _buildNameInput(),
                        const SizedBox(height: 32),
                        // 👇 تعديل الموقع فوق الأصوات والاهتزاز
                        _buildLocationBox(),
                        const SizedBox(height: 12),
                        _buildSoundsSection(),
                      ],
                    ),
                  ),
                ),
              ),
              // في الأفقي مع الكيبورد نخفي الأزرار السفلية عشان ما تاكل المساحة
              if (!(isLandscape && keyboardOpen)) _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── بوكس فيديو لغة الإشارة (يظهر فقط لما الوضع مفعّل) ─────────────────────
  Widget _buildSignVideoBox() {
    return ValueListenableBuilder<bool>(
      valueListenable: signLanguageModeNotifier,
      builder: (context, isActive, _) => AnimatedSize(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: isActive
            ? Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SignVideoCard(
                  key: const ValueKey('sign_video_card'),
                  videoAsset: _kSignVideoAsset,
                  onClose: () => signLanguageModeNotifier.value = false,
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 64, bottom: 20, right: 20, left: 20),
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
                    border: Border.all(color: const Color(0xFF181059), width: 1.5),
                  ),
                  child: const Directionality(
                    textDirection: TextDirection.ltr,
                    child: Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF181059), size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isEditing ? 'تعديل الفئة' : 'إضافة فئة',
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181059),
                ),
              ),
            ],
          ),
          ValueListenableBuilder<bool>(
            valueListenable: signLanguageModeNotifier,
            builder: (context, isActive, _) => GestureDetector(
              onTap: () => signLanguageModeNotifier.value = !isActive,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF0B4D2C),
                            Color(0xFF0B4D2C),
                            NabeehColors.green,
                          ],
                          stops: [0.09, 0.30, 1.0],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : const LinearGradient(
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
          ),
        ],
      ),
    );
  }

  Widget _buildNameInput() {
    final hasError = _nameError != null;
    final errorBorder = const Color(0xFFE53935);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اسم الفئة',
          style: TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: NabeehColors.dark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          textDirection: TextDirection.rtl,
          keyboardType: TextInputType.text,
          // يخلي الحقل ظاهر فوق الكيبورد (مهم بالوضع الأفقي)
          scrollPadding: const EdgeInsets.only(bottom: 120),
          onChanged: (_) {
            if (_nameError != null) setState(() => _nameError = null);
          },
          style: const TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 16),
          decoration: InputDecoration(
            hintText: 'مثلاً: المنزل، العمل...',
            hintTextDirection: TextDirection.rtl,
            hintStyle: const TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: NabeehColors.slate400,
            ),
            // الخلفية ثابتة — الأحمر على الحواف فقط
            filled: true,
            fillColor: NabeehColors.slate50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? errorBorder : NabeehColors.slate200,
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? errorBorder : NabeehColors.slate200,
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError ? errorBorder : NabeehColors.lightBlue,
                width: 2,
              ),
            ),
          ),
        ),
        if (hasError) ...[
  const SizedBox(height: 10),
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEBEB),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: errorBorder, width: 1.2),
    ),
    child: Row(
      children: [
        const Icon(LucideIcons.alertCircle,
            size: 16, color: Color(0xFFD32F2F)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _nameError!,
            style: const TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFD32F2F),
            ),
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
            fontFamily: 'IBMPlexSansArabic',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: NabeehColors.dark,
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

  // ─── تفعيل المجموعة حسب الموقع ─────────────────────────────────────────────

  bool get _isLocationOn => _locationTrigger?.isEnabled ?? false;

  /// يطلب صلاحية الموقع — بدونها التفعيل التلقائي ما يقدر يشتغل
  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      return true;
    }
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('لازم تسمح للتطبيق بالوصول للموقع'),
        action: permission == LocationPermission.deniedForever
            ? SnackBarAction(
                label: 'الإعدادات',
                onPressed: Geolocator.openAppSettings,
              )
            : null,
      ),
    );
    return false;
  }

  Future<void> _pickLocation() async {
    if (!await _ensureLocationPermission() || !mounted) return;
    final picked = await Navigator.push<LocationTriggerModel>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initial: _locationTrigger),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _locationTrigger = picked);
    }
  }

  Future<void> _toggleLocation(bool on) async {
    if (!on) {
      setState(() => _locationTrigger = _locationTrigger?.copyWith(isEnabled: false));
      return;
    }
    // أول مرة: لازم يختار المكان. بعدها نرجّع آخر مكان محفوظ مباشرة.
    if (_locationTrigger == null) {
      await _pickLocation();
    } else if (await _ensureLocationPermission()) {
      setState(() => _locationTrigger = _locationTrigger!.copyWith(isEnabled: true));
    }
  }

  Widget _buildLocationBox() {
    final isOn = _isLocationOn;
    final trigger = _locationTrigger;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOn ? NabeehColors.darkBlue : NabeehColors.slate100,
          width: isOn ? 1.8 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isOn
                      ? NabeehColors.darkBlue.withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  LucideIcons.mapPin,
                  size: 18,
                  color: isOn ? NabeehColors.darkBlue : NabeehColors.slate400,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'التفعيل حسب الموقع',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: isOn ? NabeehColors.dark : NabeehColors.slate500,
                  ),
                ),
              ),
              Switch(
                value: isOn,
                onChanged: _toggleLocation,
                activeThumbColor: NabeehColors.background,
                activeTrackColor: NabeehColors.darkBlue,
                inactiveThumbColor: NabeehColors.slate400,
                inactiveTrackColor: NabeehColors.slate200,
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              ),
            ],
          ),
          if (isOn && trigger != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 150,
                child: LocationPreviewMap(trigger: trigger),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(LucideIcons.radar,
                    size: 16, color: NabeehColors.slate500),
                const SizedBox(width: 6),
                Text(
                  'النطاق: ${trigger.radiusMeters.round()} م',
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 14,
                    color: NabeehColors.slate600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickLocation,
                  icon: const Icon(LucideIcons.pencil, size: 16),
                  label: const Text(
                    'تغيير الموقع',
                    style: TextStyle(
                      fontFamily: 'IBMPlexSansArabic',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: NabeehColors.darkBlue,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _soundIcon(String soundId) {
    switch (soundId) {
      case 'fire_alarm': return LucideIcons.flame;
      case 'door_bell':  return LucideIcons.bell;
      case 'door_knock': return Icons.sensor_door;
      case 'baby_cry':   return LucideIcons.baby;
      case 'adhan':      return Icons.mosque;
      default:           return LucideIcons.volume2;
    }
  }

  /// سويتش مخصص: لو إنذار الحريق يظهر القفل داخل الزر (على الـ thumb)
/// سويتش مخصص: لو إنذار الحريق يظهر القفل واضح داخل الزر (على الـ thumb)
/// سويتش مخصص: لو إنذار الحريق يظهر القفل داخل الزر (على الـ thumb)
/// سويتش مخصص: لو إنذار الحريق يظهر القفل داخل الزر (على الـ thumb)
Widget _buildSoundSwitch({
  required bool value,
  required bool locked,
  required ValueChanged<bool>? onChanged,
}) {
  if (!locked) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: NabeehColors.background,
      activeTrackColor: NabeehColors.darkBlue,
      inactiveThumbColor: NabeehColors.slate400,
      inactiveTrackColor: NabeehColors.slate200,
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }

  // مقفول: اللون الرمادي الأصلي + القفل داخل الـ thumb
  return Theme(
    data: Theme.of(context).copyWith(
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(NabeehColors.slate400),
        trackColor: WidgetStateProperty.all(NabeehColors.slate300),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        thumbIcon: WidgetStateProperty.all(
          const Icon(LucideIcons.lock, size: 14, color: Colors.white),
        ),
      ),
    ),
    child: const Switch(
      value: true,
      onChanged: null,
    ),
  );
}
  Widget _buildSoundItem(int index) {
    final sound = _sounds[index];
    final isFireAlarm = sound.soundId == 'fire_alarm';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: sound.isEnabled
              ? NabeehColors.darkBlue
              : NabeehColors.slate100,
          width: sound.isEnabled ? 1.8 : 1.0,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: sound.isEnabled
                      ? NabeehColors.darkBlue.withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _soundIcon(sound.soundId),
                  size: 18,
                  color: sound.isEnabled ? NabeehColors.darkBlue : NabeehColors.slate400,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sound.name,
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: sound.isEnabled ? NabeehColors.dark : NabeehColors.slate500,
                  ),
                ),
              ),
              _buildSoundSwitch(
                value: sound.isEnabled,
                locked: isFireAlarm,
                onChanged: isFireAlarm
                    ? null
                    : (val) => setState(
                        () => _sounds[index] = sound.copyWith(isEnabled: val)),
              ),
            ],
          ),
          if (sound.isEnabled) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFDBEAFE)),
            const SizedBox(height: 16),
            _buildVibrationSlider(index),
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
                  fontSize: 15,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: NabeehColors.background,
        border: Border(top: BorderSide(color: NabeehColors.slate100)),
      ),
      child: Row(
        children: [
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
                onPressed: _isSaving ? null : _handleSave,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  isEditing ? 'تحديث الفئة' : 'إضافة الفئة',
                  style: const TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color.fromARGB(255, 235, 233, 229),
                  width: 1.5,
                ),
              ),
              child: TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 16,
                    color: NabeehColors.slate500,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DeletedCategoryResult {
  final String id;
  final String? activatedId;
  const DeletedCategoryResult(this.id, {this.activatedId});
}
