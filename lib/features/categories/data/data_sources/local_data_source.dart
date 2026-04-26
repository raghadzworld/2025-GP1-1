import 'package:hive_flutter/hive_flutter.dart';
import '../models/category_model.dart';

class LocalDataSource {
  static const _categoriesBox = 'categories';
  static const _pendingSyncBox = 'pending_sync';
  static const _metaBox = 'cache_meta';
  static const _cacheTimestampKey = 'last_synced';
  static const _staleAfter = Duration(minutes: 5);
  static bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _initialized = true;
  }

  Future<Box<dynamic>> _getCategoriesBox() async {
    await init();
    if (!Hive.isBoxOpen(_categoriesBox)) {
      return Hive.openBox<dynamic>(_categoriesBox);
    }
    return Hive.box<dynamic>(_categoriesBox);
  }

  Future<Box<String>> _getPendingSyncBox() async {
    await init();
    if (!Hive.isBoxOpen(_pendingSyncBox)) {
      return Hive.openBox<String>(_pendingSyncBox);
    }
    return Hive.box<String>(_pendingSyncBox);
  }

  Future<Box<dynamic>> _getMetaBox() async {
    await init();
    if (!Hive.isBoxOpen(_metaBox)) {
      return Hive.openBox<dynamic>(_metaBox);
    }
    return Hive.box<dynamic>(_metaBox);
  }

  // ─── Cache staleness ────────────────────────────────────────────────────────

  Future<bool> isCacheStale() async {
    final box = await _getMetaBox();
    final ts = box.get(_cacheTimestampKey) as int?;
    if (ts == null) return true;
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts));
    return age > _staleAfter;
  }

  Future<void> updateCacheTimestamp() async {
    final box = await _getMetaBox();
    await box.put(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  // ─── Categories ─────────────────────────────────────────────────────────────

  Future<List<CategoryModel>> getAllCategories() async {
    final box = await _getCategoriesBox();
    return box.values
        .map((v) => CategoryModel.fromMap(Map<String, dynamic>.from(v as Map)))
        .toList();
  }

  Future<void> saveCategory(CategoryModel category) async {
    final box = await _getCategoriesBox();
    await box.put(category.id, category.toMap());
  }

  Future<void> deleteCategory(String id) async {
    final box = await _getCategoriesBox();
    await box.delete(id);
  }

  Future<void> replaceAllCategories(List<CategoryModel> categories) async {
    final box = await _getCategoriesBox();
    await box.clear();
    for (final cat in categories) {
      await box.put(cat.id, cat.toMap());
    }
  }

  // ─── Pending sync queue ─────────────────────────────────────────────────────

  Future<void> addToPendingSync(String categoryId, String operation) async {
    final box = await _getPendingSyncBox();
    await box.put(categoryId, operation);
  }

  Future<Map<String, String>> getPendingSyncs() async {
    final box = await _getPendingSyncBox();
    return Map<String, String>.from(box.toMap());
  }

  Future<void> removeFromPendingSync(String categoryId) async {
    final box = await _getPendingSyncBox();
    await box.delete(categoryId);
  }

  // ─── Full reset (logout) ────────────────────────────────────────────────────

  Future<void> clearAll() async {
    final catBox = await _getCategoriesBox();
    await catBox.clear();
    final syncBox = await _getPendingSyncBox();
    await syncBox.clear();
    final metaBox = await _getMetaBox();
    await metaBox.clear();
  }
}
