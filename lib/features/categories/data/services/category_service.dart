import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/category_model.dart';
import '../models/sound_setting_model.dart';
import '../repositories/category_repository.dart';

class CategoryService {
  final CategoryRepository _repository;

  CategoryService(this._repository);

  CategoryService.withDefaults() : _repository = CategoryRepository();

  static List<SoundSettingModel> get _defaultSounds => [
        const SoundSettingModel(
          soundId: 'fire_alarm',
          name: 'إنذار الحريق',
          isEmergency: true,
          isEnabled: true,
          vibrationPower: 3,
          vibrationPattern: 1,
        ),
        const SoundSettingModel(
          soundId: 'door_bell',
          name: 'جرس الباب',
          isEmergency: false,
          isEnabled: true,
          vibrationPower: 2,
          vibrationPattern: 1,
        ),
        const SoundSettingModel(
          soundId: 'door_knock',
          name: 'طرق على الباب',
          isEmergency: false,
          isEnabled: true,
          vibrationPower: 2,
          vibrationPattern: 1,
        ),
        const SoundSettingModel(
          soundId: 'baby_cry',
          name: 'بكاء طفل',
          isEmergency: false,
          isEnabled: true,
          vibrationPower: 2,
          vibrationPattern: 1,
        ),
        const SoundSettingModel(
          soundId: 'adhan',
          name: 'الآذان',
          isEmergency: false,
          isEnabled: true,
          vibrationPower: 2,
          vibrationPattern: 1,
        ),
      ];

  // ─── App start / Login ──────────────────────────────────────────────────────

  Future<void> initializeForUser() async {
    await _repository.refreshFromFirebase();
    await _createDefaultIfEmpty();
  }

  Future<void> _createDefaultIfEmpty() async {
    final existing = await _repository.getAll();
    if (existing.isNotEmpty) return;

    final defaultCategory = CategoryModel(
      id: _generateId(),
      name: 'المجموعة الافتراضية',
      isEnabled: true,
      sounds: _defaultSounds,
    );
    await _repository.save(defaultCategory);
  }

  // ─── CRUD ───────────────────────────────────────────────────────────────────

  Future<List<CategoryModel>> getCategories() => _repository.getAll();

  Future<void> addCategory(CategoryModel category) async {
    final id = category.id.isEmpty ? _generateId() : category.id;
    final model = CategoryModel(
      id: id,
      name: category.name,
      isEnabled: category.isEnabled,
      sounds: _enforceFireAlarmInList(category.sounds),
    );
    await _repository.save(model);
  }

  Future<void> editCategory(CategoryModel category) async {
    final validated = CategoryModel(
      id: category.id,
      name: category.name,
      isEnabled: category.isEnabled,
      sounds: _enforceFireAlarmInList(category.sounds),
    );
    await _repository.save(validated);
  }

  Future<void> deleteCategory(String id) async {
    final categories = await _repository.getAll();
    if (categories.length <= 1) {
      throw StateError('Cannot delete the last category');
    }
    final wasActive = categories.any((c) => c.id == id && c.isEnabled);
    await _repository.delete(id);
    if (wasActive) {
      final remaining = await _repository.getAll();
      if (remaining.isNotEmpty) {
        await _repository.save(remaining.first.copyWith(isEnabled: true));
      }
    }
  }

  Future<void> setActiveCategory(String id) async {
    final categories = await _repository.getAll();
    for (final category in categories) {
      final shouldBeEnabled = category.id == id;
      if (category.isEnabled != shouldBeEnabled) {
        await _repository.save(category.copyWith(isEnabled: shouldBeEnabled));
      }
    }
  }

  // ─── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    await _repository.clearAll();
    await FirebaseAuth.instance.signOut();
  }

  // ─── Backward compat ────────────────────────────────────────────────────────

  Future<void> createDefaultCategoryForNewUser() async {
    await _createDefaultIfEmpty();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  List<SoundSettingModel> _enforceFireAlarmInList(
    List<SoundSettingModel> sounds,
  ) {
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
