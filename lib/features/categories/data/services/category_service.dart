import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../data_sources/firebase_data_source.dart';
import '../models/category_model.dart';
import '../models/sound_setting_model.dart';

class CategoryService {
  final FirebaseDataSource _firebase;

  CategoryService(this._firebase);

  CategoryService.withDefaults() : _firebase = FirebaseDataSource();

  static const List<SoundSettingModel> defaultSounds = [
    SoundSettingModel(
      soundId: 'fire_alarm',
      name: 'إنذار الحريق',
      isEmergency: true,
      isEnabled: true,
      vibrationPower: 3,
      vibrationPattern: 1,
    ),
    SoundSettingModel(
      soundId: 'door_bell',
      name: 'جرس الباب',
      isEmergency: false,
      isEnabled: true,
      vibrationPower: 2,
      vibrationPattern: 1,
    ),
    SoundSettingModel(
      soundId: 'door_knock',
      name: 'طرق على الباب',
      isEmergency: false,
      isEnabled: true,
      vibrationPower: 2,
      vibrationPattern: 1,
    ),
    SoundSettingModel(
      soundId: 'baby_cry',
      name: 'بكاء طفل',
      isEmergency: false,
      isEnabled: true,
      vibrationPower: 2,
      vibrationPattern: 1,
    ),
    SoundSettingModel(
      soundId: 'adhan',
      name: 'الآذان',
      isEmergency: false,
      isEnabled: true,
      vibrationPower: 2,
      vibrationPattern: 1,
    ),
  ];

  // ─── App start ──────────────────────────────────────────────────────────────

  Future<List<CategoryModel>> initializeForUser() async {
    final existing = await _firebase.getAllCategories();
    if (existing.isNotEmpty) return existing;

    final defaultCategory = CategoryModel(
      id: _generateId(),
      name: 'المجموعة الافتراضية',
      isEnabled: true,
      sounds: defaultSounds,
    );
    await _firebase.saveCategory(defaultCategory);
    return [defaultCategory];
  }

  // ─── CRUD ───────────────────────────────────────────────────────────────────

  Future<List<CategoryModel>> getCategories() => _firebase.getAllCategories();

  Future<CategoryModel> addCategory(CategoryModel category) async {
    final id = category.id.isEmpty ? _generateId() : category.id;
    final model = CategoryModel(
      id: id,
      name: category.name,
      isEnabled: category.isEnabled,
      sounds: _enforceFireAlarmInList(category.sounds),
    );
    await _firebase.saveCategory(model);
    return model;
  }

  Future<void> editCategory(CategoryModel category) async {
    final validated = CategoryModel(
      id: category.id,
      name: category.name,
      isEnabled: category.isEnabled,
      sounds: _enforceFireAlarmInList(category.sounds),
    );
    await _firebase.saveCategory(validated);
  }

  // يُرجع ID الفئة التي فُعِّلت تلقائياً (أو null إذا لم تكن المحذوفة نشطة)
  Future<String?> deleteCategory(
    String id, {
    List<CategoryModel>? currentCategories,
  }) async {
    final categories =
        currentCategories ?? await _firebase.getAllCategories();
    if (categories.length <= 1) {
      throw StateError('Cannot delete the last category');
    }

    final wasActive = categories.any((c) => c.id == id && c.isEnabled);
    await _firebase.deleteCategory(id);

    if (wasActive) {
      final idx = categories.indexWhere((c) => c.id == id);
      final remaining = categories.where((c) => c.id != id).toList();
      if (remaining.isNotEmpty) {
        final nextIdx = idx < remaining.length ? idx : remaining.length - 1;
        final toActivate = remaining[nextIdx];
        await _firebase.saveCategory(toActivate.copyWith(isEnabled: true));
        return toActivate.id;
      }
    }
    return null;
  }

  Future<void> setActiveCategory(
    String id, {
    List<CategoryModel>? currentCategories,
  }) async {
    final categories =
        currentCategories ?? await _firebase.getAllCategories();
    final toUpdate = categories.where((c) => (c.id == id) != c.isEnabled);
    await Future.wait(
      toUpdate.map((c) => _firebase.saveCategory(
            c.copyWith(isEnabled: c.id == id),
          )),
    );
  }

  // ─── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  List<SoundSettingModel> enforceFireAlarm(List<SoundSettingModel> sounds) =>
      _enforceFireAlarmInList(sounds);

  List<SoundSettingModel> _enforceFireAlarmInList(
      List<SoundSettingModel> sounds) {
    return sounds.map((s) {
      if (s.soundId == 'fire_alarm' && !s.isEnabled) {
        return s.copyWith(isEnabled: true);
      }
      return s;
    }).toList();
  }

  String _generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(99999).toString().padLeft(5, '0');
    return '${ts}_$rand';
  }
}
