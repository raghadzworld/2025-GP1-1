import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/custom_widgets.dart';
import 'Nabeeh_Colors.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  // Local state for demonstration (will be replaced by Provider later)
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
          {'name': 'الآذان', 'vibration': 'قوي'},
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

  IconData _getIconFromName(String name) {
    switch (name) {
      case 'Home':
        return LucideIcons.home;
      case 'Work':
        return LucideIcons.briefcase;
      case 'Outdoor':
        return LucideIcons.trees;
      case 'Travel':
        return LucideIcons.car;
      default:
        return LucideIcons.home;
    }
  }

  void _setActiveCategory(int index) {
    setState(() {
      for (int i = 0; i < _categories.length; i++) {
        _categories[i]['active'] = i == index;
      }
    });
  }

Future<void> _navigateToAddEdit({Map<String, dynamic>? category, int? index}) async {
  final result = await Navigator.pushNamed(
    context,
    '/add-category',
    arguments: category,
  );
  
  if (result == 'DELETE') {
    // Category was deleted
    if (index != null) {
      setState(() {
        _categories.removeAt(index);
        if (_categories.isNotEmpty && !_categories.any((c) => c['active'] == true)) {
          _categories[0]['active'] = true;
        }
      });
    }
  } else if (result != null && result is Map<String, dynamic>) {
    setState(() {
      if (index != null) {
        _categories[index] = result;
      } else {
        result['active'] = false;
        _categories.add(result);
      }
    });
  }
}

  void _deleteCategory(int index) {
    setState(() {
      _categories.removeAt(index);
      // If the active one was deleted, activate the first remaining if any
      if (_categories.isNotEmpty && !_categories.any((c) => c['active'] == true)) {
        _categories[0]['active'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 64),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تخصيص البيئة',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: NabeehColors.slate400,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'فئات الأصوات',
                        style: TextStyle(
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
                        boxShadow: [
                          BoxShadow(
                            color: NabeehColors.dark.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(LucideIcons.arrowLeft, color: NabeehColors.slate400),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Category List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  ..._categories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final cat = entry.value;
                    return Column(
                      children: [
                        _buildCategoryCard(
                          context,
                          iconName: cat['iconName'],
                          name: cat['name'],
                          desc: cat['desc'],
                          count: (cat['sounds'] as List).length,
                          active: cat['active'] ?? false,
                          sounds: List<Map<String, dynamic>>.from(cat['sounds']),
                          onEdit: () => _navigateToAddEdit(category: cat, index: index),
                          onDelete: () => _deleteCategory(index),
                          onActivate: () => _setActiveCategory(index),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  }),
                  const SizedBox(height: 4),

                  GestureDetector(
                    onTap: () => _navigateToAddEdit(),
                    child: Container(
                      width: double.infinity,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: NabeehColors.slate200, width: 2),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.plus, color: NabeehColors.slate400),
                          SizedBox(width: 8),
                          Text(
                            'إضافة فئة جديدة',
                            style: TextStyle(
                              color: NabeehColors.slate400,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String iconName,
    required String name,
    required String desc,
    required int count,
    required bool active,
    required List<Map<String, dynamic>> sounds,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    required VoidCallback onActivate,
  }) {
    return BentoCard(
      border: active ? Border.all(color: NabeehColors.accent, width: 2) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: active ? NabeehColors.accent : NabeehColors.slate50,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: NabeehColors.accent.withValues(alpha: 0.2),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      _getIconFromName(iconName),
                      color: active ? NabeehColors.dark : NabeehColors.slate400,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$count أصوات مراقبة',
                        style: const TextStyle(
                          fontSize: 10,
                          color: NabeehColors.slate400,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? NabeehColors.accent.withValues(alpha: 0.2) : NabeehColors.slate100,
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
            children: sounds.map((s) => _buildSoundChip(s['name'], vibration: s['vibration'])).toList(),
          ),

          const SizedBox(height: 24),
          const Divider(color: NabeehColors.slate50),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildActionButton(context, LucideIcons.edit2, onTap: onEdit),
                  const SizedBox(width: 8),
                  _buildActionButton(context, LucideIcons.trash2, isDanger: true, onTap: onDelete),
                ],
              ),

                          if (!active)
                Flexible(                                          // ✅ هذا هو التغيير الوحيد
                  child: ElevatedButton(
                    onPressed: onActivate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NabeehColors.dark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      'تفعيل الفئة',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                )
              else
                const Row(
                  children: [
                    Icon(LucideIcons.checkCircle2, color: NabeehColors.accent, size: 16),
                    SizedBox(width: 8),
                    Text(
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
        ],
      ),
    );
  }

  Widget _buildSoundChip(String label, {required String vibration}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: NabeehColors.slate50,
            border: Border.all(color: NabeehColors.slate100),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: NabeehColors.slate400,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(LucideIcons.activity, size: 8, color: NabeehColors.accent),
            const SizedBox(width: 4),
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
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, {bool isDanger = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDanger ? const Color(0xFFFEF2F2) : NabeehColors.slate50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isDanger ? Colors.red.shade400 : NabeehColors.slate400,
          size: 16,
        ),
      ),
    );
  }



  
}