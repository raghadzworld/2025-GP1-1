import 'package:flutter/material.dart';
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
      final wasActive =
          _categories.any((c) => c.id == result.id && c.isEnabled);
      setState(() {
        _categories = _categories.where((c) => c.id != result.id).toList();
        if (wasActive && _categories.isNotEmpty) {
          _categories[0] = _categories[0].copyWith(isEnabled: true);
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
                      style:
                          const TextStyle(fontFamily: 'IBMPlexSansArabic'),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              const SizedBox(height: 4),
                              ..._categories.map(
                                (cat) => Column(
                                  children: [
                                    _buildCategoryCard(cat),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _navigateToAddEdit(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: NabeehColors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  elevation: 0,
                                  minimumSize:
                                      const Size(double.infinity, 48),
                                ),
                                child: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'إضافة مجموعة جديدة',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
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
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: NabeehColors.dark,
                  size: 18,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'المجموعات الصوتية',
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

  Widget _buildCategoryCard(CategoryModel category) {
    final isOnlyOne = _categories.length <= 1;
    final enabledSounds =
        category.sounds.where((s) => s.isEnabled).toList();

    return BentoCard(
      border: category.isEnabled
          ? Border.all(color: const Color(0xFF1773CF), width: 2)
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
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: NabeehColors.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${enabledSounds.length} أصوات مراقبة',
                      style: const TextStyle(
                        fontSize: 10,
                        color: NabeehColors.slate400,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: category.isEnabled
                      ? const Color(0xFFFFD350).withValues(alpha: 0.2)
                      : NabeehColors.slate100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category.isEnabled ? 'نشط' : 'غير نشط',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
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
              TextButton(
                onPressed: () => _navigateToAddEdit(category: category),
                style: TextButton.styleFrom(
                  foregroundColor: NabeehColors.blue,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'تعديل',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed:
                    isOnlyOne ? null : () => _deleteCategory(category.id),
                style: TextButton.styleFrom(
                  backgroundColor: isOnlyOne
                      ? NabeehColors.slate100
                      : Colors.red.withValues(alpha: 0.08),
                  foregroundColor:
                      isOnlyOne ? NabeehColors.slate300 : Colors.red,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'حذف',
                  style:
                      TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              if (!category.isEnabled)
                Flexible(
                  child: ElevatedButton(
                    onPressed: () => _setActiveCategory(category.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NabeehColors.dark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'تفعيل المجموعة',
                        maxLines: 1,
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                  ),
                )
              else
                const Text(
                  'مفعل حالياً',
                  style: TextStyle(
                    color: NabeehColors.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
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
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: NabeehColors.slate400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'اهتزاز ${_intensityLabel(sound.vibrationPower)} · ${_intensityLabel(sound.vibrationPattern)}',
            style: const TextStyle(
              fontSize: 8,
              color: NabeehColors.slate300,
              fontWeight: FontWeight.w900,
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
