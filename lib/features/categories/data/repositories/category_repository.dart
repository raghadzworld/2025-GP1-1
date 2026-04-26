import '../data_sources/firebase_data_source.dart';
import '../data_sources/local_data_source.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final LocalDataSource _local;
  final FirebaseDataSource _firebase;

  CategoryRepository({
    LocalDataSource? local,
    FirebaseDataSource? firebase,
  })  : _local = local ?? LocalDataSource(),
        _firebase = firebase ?? FirebaseDataSource();

  // ─── Initialization ─────────────────────────────────────────────────────────

  Future<void> refreshFromFirebase() async {
    try {
      await _flushPendingSync();
      final remote = await _firebase.getAllCategories();
      await _local.replaceAllCategories(remote);
      await _local.updateCacheTimestamp();
    } catch (_) {
      // Offline or unauthenticated — keep existing Hive cache.
    }
  }

  // ─── Read (Hive-first, staleness-aware) ─────────────────────────────────────

  Future<List<CategoryModel>> getAll() async {
    await _flushPendingSync();

    final cached = await _local.getAllCategories();
    final isStale = await _local.isCacheStale();

    if (cached.isEmpty || isStale) {
      try {
        final remote = await _firebase.getAllCategories();
        await _local.replaceAllCategories(remote);
        await _local.updateCacheTimestamp();
        return remote;
      } catch (_) {
        // Offline — fall through and return whatever Hive has.
      }
    }

    return cached;
  }

  // ─── Write (Firebase-first) ─────────────────────────────────────────────────

  Future<void> save(CategoryModel category) async {
    try {
      await _firebase.saveCategory(category);
      await _local.saveCategory(category);
      await _local.removeFromPendingSync(category.id);
      await _local.updateCacheTimestamp();
    } catch (_) {
      await _local.saveCategory(category);
      await _local.addToPendingSync(category.id, 'upsert');
    }
  }

  Future<void> delete(String id) async {
    try {
      await _firebase.deleteCategory(id);
      await _local.deleteCategory(id);
      await _local.removeFromPendingSync(id);
    } catch (_) {
      await _local.deleteCategory(id);
      await _local.addToPendingSync(id, 'delete');
    }
  }

  // ─── Logout ─────────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _local.clearAll();
  }

  // ─── Pending sync ───────────────────────────────────────────────────────────

  Future<void> _flushPendingSync() async {
    final pending = await _local.getPendingSyncs();
    if (pending.isEmpty) return;

    for (final entry in pending.entries) {
      try {
        if (entry.value == 'upsert') {
          final all = await _local.getAllCategories();
          final match = all.where((c) => c.id == entry.key).toList();
          if (match.isNotEmpty) {
            await _firebase.saveCategory(match.first);
          }
        } else {
          await _firebase.deleteCategory(entry.key);
        }
        await _local.removeFromPendingSync(entry.key);
      } catch (_) {
        continue;
      }
    }
  }
}
