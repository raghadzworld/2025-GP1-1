import 'package:flutter/material.dart';


import '../widgets/custom_widgets.dart';
import 'nabeeh_colors.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late List<Map<String, dynamic>> _categories;

  @override
  void initState() {
    super.initState();
    _categories = [
      {
        'name': 'المنزل',
        'desc': 'تنبيهات المنزل الأساسية والاستجابة للأصوات المحيطة',
        'iconName': 'Home',
        'active': true,
        'sounds': [
          {'name': 'الأذان', 'vibration': 'قوي'},
          {'name': 'بكاء طفل', 'vibration': 'متوسط'},
          {'name': 'طرق على الباب', 'vibration': 'ضعيف'},
        ],
      },
      {
        'name': 'العمل',
        'desc': 'تنبيهات بيئة العمل والاجتماعات',
        'iconName': 'Work',
        'active': false,
        'sounds': [
          {'name': 'إنذار الحريق', 'vibration': 'قوي'},
          {'name': 'طرق على الباب', 'vibration': 'متوسط'},
        ],
      },
    ];
  }

  void _setActiveCategory(int index) {
    setState(() {
      for (int i = 0; i < _categories.length; i++) {
        _categories[i]['active'] = i == index;
      }
    });
  }

  Future<void> _navigateToAddEdit({
    Map<String, dynamic>? category,
    int? index,
  }) async {
    final result = await Navigator.pushNamed(
      context,
      '/add-category',
      arguments: category,
    );

    if (result == 'DELETE') {
      if (index != null) {
        setState(() {
          _categories.removeAt(index);
          if (_categories.isNotEmpty &&
              !_categories.any((c) => c['active'] == true)) {
            _categories[0]['active'] = true;
          }
        });
      }
      return;
    }

    if (result != null && result is Map<String, dynamic>) {
      final updatedCategory = Map<String, dynamic>.from(result);
      setState(() {
        if (index != null) {
          updatedCategory['active'] = _categories[index]['active'] ?? false;
          _categories[index] = updatedCategory;
        } else {
          updatedCategory['active'] = false;
          _categories.add(updatedCategory);
        }
      });
    }
  }

  void _deleteCategory(int index) {
    setState(() {
      _categories.removeAt(index);
      if (_categories.isNotEmpty && !_categories.any((c) => c['active'] == true)) {
        _categories[0]['active'] = true;
      }
    });
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
                style: const TextStyle(
                  fontFamily: 'IBMPlexSansArabic',
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        ..._categories.asMap().entries.map((entry) {
                          final index = entry.key;
                          final cat = entry.value;
                          return Column(
                            children: [
                              _buildCategoryCard(
                                name: cat['name'] as String,
                                desc: cat['desc'] as String,
                                count: (cat['sounds'] as List).length,
                                active: cat['active'] as bool? ?? false,
                                sounds: List<Map<String, dynamic>>.from(cat['sounds'] as List),
                                onEdit: () => _navigateToAddEdit(category: cat, index: index),
                                onDelete: () => _deleteCategory(index),
                                onActivate: () => _setActiveCategory(index),
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        }),
                      ElevatedButton(
  onPressed: () => _navigateToAddEdit(),
  style: ElevatedButton.styleFrom(
    backgroundColor: NabeehColors.blue, // لون الإضافة يمكن تغييره حسب رغبتك
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18), // نفس تدوير أزرار التفعيل
    ),
    elevation: 0,
    minimumSize: const Size(double.infinity, 48), // يجعل الزر بعرض كامل
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

  // ─── Custom Header (unchanged) ───────────────────────────────────────────────
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'المجموعات الصوتية',
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

  Widget _buildCategoryCard({
  required String name,
  required String desc,
  required int count,
  required bool active,
  required List<Map<String, dynamic>> sounds,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  required VoidCallback onActivate,
}) {
  const Color activeBorderColor = Color(0xFF1773CF);

  return BentoCard(
    border: active ? Border.all(color: activeBorderColor, width: 2) : null,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,  // ← THIS FIXES THE LAYOUT
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: NabeehColors.dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count أصوات مراقبة',
                    style: const TextStyle(
                      fontSize: 10,
                      color: NabeehColors.slate400,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: NabeehColors.slate500,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFFFD350).withValues(alpha: 0.2)
                    : NabeehColors.slate100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                active ? 'نشط' : 'غير نشط',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: active ? NabeehColors.accent : NabeehColors.slate400,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          textDirection: TextDirection.rtl,
          spacing: 8,
          runSpacing: 8,
          children: sounds
              .map((sound) => _buildSoundChip(
                    sound['name'] as String,
                    vibration: sound['vibration'] as String,
                  ))
              .toList(),
        ),
        const SizedBox(height: 24),
        const Divider(color: NabeehColors.slate50),
        const SizedBox(height: 24),
        Row(
          children: [
            TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                 foregroundColor: NabeehColors.blue ,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'تعديل',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
           TextButton(
  onPressed: onDelete,
  style: TextButton.styleFrom(
    backgroundColor: Colors.red.withValues(alpha: 0.08),
    foregroundColor: Colors.red,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  ),
              child: const Text(
                'حذف',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const Spacer(),
            if (!active)
              Flexible(
  child: ElevatedButton(
    onPressed: onActivate,
    style: ElevatedButton.styleFrom(
      backgroundColor: NabeehColors.dark,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // ← قللنا البادينق
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      elevation: 0,
    ),
    child: const FittedBox( // ← هذا أهم سطر
      fit: BoxFit.scaleDown,
      child: Text(
        'تفعيل المجموعة',
        maxLines: 1, // ← يمنع النزول لسطر ثاني
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
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

  Widget _buildSoundChip(String label, {required String vibration}) {
    // Removed the activity icon
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
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: NabeehColors.slate400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'اهتزاز $vibration',
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
}
