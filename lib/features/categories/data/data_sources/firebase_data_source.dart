import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/category_model.dart';
import '../models/sound_setting_model.dart';

class FirebaseDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirebaseDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _categoriesRef() {
    final uid = _userId;
    if (uid == null) throw StateError('No authenticated user');
    return _firestore.collection('User').doc(uid).collection('SoundCategories');
  }

  Future<List<CategoryModel>> getAllCategories() async {
    final uid = _userId;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection('User')
        .doc(uid)
        .collection('SoundCategories')
        .get();

    // جلب أصوات كل الفئات بالتوازي بدلاً من واحدة واحدة
    final soundFutures = snapshot.docs
        .map((doc) => doc.reference.collection('Sounds').get());
    final soundSnapshots = await Future.wait(soundFutures);

    final categories = <CategoryModel>[];
    for (var i = 0; i < snapshot.docs.length; i++) {
      final doc = snapshot.docs[i];
      final sounds = soundSnapshots[i].docs.map((s) {
        final data = Map<String, dynamic>.from(s.data());
        data['soundId'] = s.id;
        return SoundSettingModel.fromMap(data);
      }).toList();

      final data = doc.data();
      categories.add(CategoryModel(
        id: doc.id,
        name: data['name'] as String? ?? '',
        isEnabled: data['isEnabled'] as bool? ?? false,
        sounds: sounds,
      ));
    }
    return categories;
  }

  Future<void> saveCategory(CategoryModel category) async {
    final catRef = _categoriesRef().doc(category.id);

    final batch = _firestore.batch();

    // كتابة بيانات الفئة والأصوات في batch واحد
    batch.set(catRef, {
      'name': category.name,
      'isEnabled': category.isEnabled,
    });

    for (final sound in category.sounds) {
      batch.set(
        catRef.collection('Sounds').doc(sound.soundId),
        {
          'name': sound.name,
          'isEmergency': sound.isEmergency,
          'isEnabled': sound.soundId == 'fire_alarm' ? true : sound.isEnabled,
          'vibrationPower': sound.vibrationPower,
          'vibrationPattern': sound.vibrationPattern,
        },
      );
    }

    await batch.commit();
  }

  static const _knownSoundIds = [
    'fire_alarm',
    'door_bell',
    'door_knock',
    'baby_cry',
    'adhan',
  ];

  Future<void> deleteCategory(String id) async {
    final catRef = _categoriesRef().doc(id);
    final batch = _firestore.batch();
    // الأصوات بـ IDs ثابتة ومعروفة — لا حاجة لقراءة Firestore قبل الحذف
    for (final soundId in _knownSoundIds) {
      batch.delete(catRef.collection('Sounds').doc(soundId));
    }
    batch.delete(catRef);
    await batch.commit();
  }
}
