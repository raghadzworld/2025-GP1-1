import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../features/categories/data/models/category_model.dart';
import '../features/categories/data/models/sound_setting_model.dart';
import '../features/categories/data/services/category_service.dart';
import '../widgets/custom_widgets.dart';
import 'nabeeh_colors.dart';
import 'add_edit_category_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final CategoryService _service = CategoryService.withDefaults();
  List<CategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final categories = await _service.initializeForUser();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر تحميل الفئات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // تحديث الفئة في الذاكرة مباشرة — يمرر القائمة الحالية لتجنب قراءة Firestore
  Future<void> _setActiveCategory(String id) async {
    try {
      await _service.setActiveCategory(id, currentCategories: _categories);
      setState(() {
        _categories = _categories
            .map((c) => c.copyWith(isEnabled: c.id == id))
            .toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('تعذّر التفعيل: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // حذف الفئة من الذاكرة مباشرة — wasActive يُحسب قبل العملية
  Future<void> _deleteCategory(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: Colors.red),
              SizedBox(width: 10),
              Text(
                'حذف المجموعة',
                style: TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في حذف هذه المجموعة نهائياً؟',
            style: TextStyle(fontFamily: 'IBMPlexSansArabic', fontSize: 16),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: OutlinedButton.styleFrom(
                      fixedSize: const Size.fromHeight(50),
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: Colors.redAccent, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.trash2, color: Colors.redAccent, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'حذف',
                          style: TextStyle(
                            fontFamily: 'IBMPlexSansArabic',
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      fixedSize: const Size.fromHeight(50),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color.fromARGB(255, 235, 233, 229)),
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
                            fontFamily: 'IBMPlexSansArabic',
                            color: NabeehColors.slate500,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
      ),
    );

    if (confirm != true) return;

    // يُحسب قبل الاستدعاء لضمان الدقة
    final wasActive = _categories.any((c) => c.id == id && c.isEnabled);
    try {
      // يمرر القائمة الحالية ويستقبل ID الفئة التي فُعِّلت (إن وُجدت)
      final activatedId = await _service.deleteCategory(
        id,
        currentCategories: _categories,
      );
      setState(() {
        _categories = _categories.where((c) => c.id != id).toList();
        if (wasActive && activatedId != null) {
          final idx = _categories.indexWhere((c) => c.id == activatedId);
          if (idx >= 0) {
            _categories[idx] = _categories[idx].copyWith(isEnabled: true);
          }
        }
      });
    } on StateError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن حذف الفئة الوحيدة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('تعذّر الحذف: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _navigateToAddEdit({CategoryModel? category}) async {
    final result = await Navigator.push<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditCategoryScreen(
          category: category,
          service: _service,
          existingCategories: _categories,
        ),
      ),
    );

    if (result == null) return;

    if (result is CategoryModel) {
      setState(() {
        final index = _categories.indexWhere((c) => c.id == result.id);
        if (index >= 0) {
          // تعديل: استبدل في مكانه
          _categories[index] = result;
        } else {
          // إضافة: أضفه للقائمة
          _categories = [..._categories, result];
        }
      });
    } else if (result is DeletedCategoryResult) {
      setState(() {
        _categories = _categories.where((c) => c.id != result.id).toList();
        if (result.activatedId != null) {
          final idx = _categories.indexWhere((c) => c.id == result.activatedId);
          if (idx >= 0) {
            _categories[idx] = _categories[idx].copyWith(isEnabled: true);
          }
        }
      });
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : DefaultTextStyle.merge(
                      style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        child: Column(
                          children: [
                            ..._categories.map(
                              (cat) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildCategoryCard(cat),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            _buildAddButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Container(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF181059), Color(0xFF1773CF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
        ),
        child: TextButton.icon(
          onPressed: () => _navigateToAddEdit(),
          icon: const Icon(LucideIcons.plus, color: Colors.white),
          label: const Text(
            'إضافة مجموعة جديدة',
            style: TextStyle(
              fontFamily: 'IBMPlexSansArabic',
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                    border: Border.all(color: const Color(0xFF181059), width: 1.5),
                  ),
                  child: const Directionality(
                    textDirection: TextDirection.ltr,
                    child: Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF181059), size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'المجموعات الصوتية',
                style: TextStyle(
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
                  colors: [NabeehColors.darkNavy, NabeehColors.darkNavy, NabeehColors.lightBlue],
                  stops: [0.09, 0.30, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
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

  Widget _buildCategoryCard(CategoryModel category) {
    final enabledSounds =
        category.sounds.where((s) => s.isEnabled).toList();

    return BentoCard(
      border: category.isEnabled
          ? Border.all(color: const Color(0xFF181059), width: 2)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: NabeehColors.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${enabledSounds.length} أصوات مراقبة',
                      style: const TextStyle(
                        fontSize: 14,
                        color: NabeehColors.slate400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: category.isEnabled
                      ? const Color(0xFFFFD350).withValues(alpha: 0.2)
                      : NabeehColors.slate100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category.isEnabled ? 'نشط' : 'غير نشط',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: category.isEnabled
                        ? NabeehColors.accent
                        : NabeehColors.slate400,
                  ),
                ),
              ),
            ],
          ),
          if (enabledSounds.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              textDirection: TextDirection.rtl,
              spacing: 8,
              runSpacing: 8,
              children: enabledSounds.map(_buildSoundChip).toList(),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(color: NabeehColors.slate50),
          const SizedBox(height: 20),
          Row(
            children: [
              if (!category.isEnabled)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF181059), Color(0xFF1773CF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: TextButton(
                    onPressed: () => _setActiveCategory(category.id),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'تفعيل المجموعة',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else
                const Text(
                  'مفعل حالياً',
                  style: TextStyle(
                    color: NabeehColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () => _navigateToAddEdit(category: category),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NabeehColors.darkBlue, width: 1.2),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.edit2, size: 13, color: NabeehColors.darkBlue),
                      SizedBox(width: 5),
                      Text(
                        'تعديل',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: NabeehColors.darkBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _categories.length <= 1 ? null : () => _deleteCategory(category.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _categories.length <= 1 ? NabeehColors.slate200 : Colors.redAccent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.trash2, size: 13,
                          color: _categories.length <= 1 ? NabeehColors.slate300 : Colors.redAccent),
                      const SizedBox(width: 5),
                      Text(
                        'حذف',
                        style: TextStyle(
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _categories.length <= 1 ? NabeehColors.slate300 : Colors.redAccent,
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

  Widget _buildSoundChip(SoundSettingModel sound) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NabeehColors.slate50,
        border: Border.all(color: NabeehColors.slate100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sound.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: NabeehColors.slate500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'اهتزاز ${_intensityLabel(sound.vibrationPower)} · ${_intensityLabel(sound.vibrationPattern)}',
            style: const TextStyle(
              fontSize: 14,
              color: NabeehColors.slate300,
              fontWeight: FontWeight.w600,
            ),
          ),
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
