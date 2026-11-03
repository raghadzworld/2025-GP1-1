import 'package:flutter_test/flutter_test.dart';
import 'package:nabbeh/features/categories/data/models/category_model.dart';
import 'package:nabbeh/features/categories/data/models/location_trigger_model.dart';
import 'package:nabbeh/services/location_category_switcher.dart';

// إحداثيات حقيقية بالرياض (المسافة تنحسب بـ Geolocator.distanceBetween)
const home = (24.7136, 46.6753);
const mosque = (24.7150, 46.6753); // تقريبًا ١٥٦م شمال البيت
const farAway = (24.7400, 46.6753); // تقريبًا ٣ كم

CategoryModel cat(
  String id, {
  bool active = false,
  (double, double)? at,
  bool triggerOn = true,
  double radius = 100,
}) => CategoryModel(
  id: id,
  name: id,
  isEnabled: active,
  sounds: const [],
  locationTrigger: at == null
      ? null
      : LocationTriggerModel(
          isEnabled: triggerOn,
          latitude: at.$1,
          longitude: at.$2,
          radiusMeters: radius,
        ),
);

LocationSwitchDecision decide(
  List<CategoryModel> cats,
  (double, double) pos, [
  LocationSwitchState state = LocationSwitchState.empty,
]) => decideLocationSwitch(
  categories: cats,
  latitude: pos.$1,
  longitude: pos.$2,
  state: state,
);

void main() {
  test('يفعّل المجموعة لما يوصل مكانها ويحفظ السابقة', () {
    final d = decide([
      cat('default', active: true),
      cat('masjid', at: mosque),
    ], mosque);
    expect(d.activateCategoryId, 'masjid');
    expect(d.newState.autoCategoryId, 'masjid');
    expect(d.newState.previousCategoryId, 'default');
  });

  test('ما يسوي شي لو بعيد عن كل الأماكن', () {
    final d = decide([
      cat('default', active: true),
      cat('masjid', at: mosque),
    ], farAway);
    expect(d.activateCategoryId, isNull);
    expect(d.newState.autoCategoryId, isNull);
  });

  test('ما يفعّل لو خيار الموقع مطفي', () {
    final d = decide([
      cat('default', active: true),
      cat('masjid', at: mosque, triggerOn: false),
    ], mosque);
    expect(d.activateCategoryId, isNull);
  });

  test('يرجّع المجموعة السابقة لما يطلع من المكان', () {
    final d = decide(
      [cat('default'), cat('masjid', active: true, at: mosque)],
      farAway,
      const LocationSwitchState(
        autoCategoryId: 'masjid',
        previousCategoryId: 'default',
      ),
    );
    expect(d.activateCategoryId, 'default');
    expect(d.newState.autoCategoryId, isNull);
  });

  test('ما يرجّع لو المستخدم غيّر المجموعة بيده قبل ما يطلع', () {
    final d = decide(
      [cat('default'), cat('masjid', at: mosque), cat('work', active: true)],
      farAway,
      const LocationSwitchState(autoCategoryId: 'masjid'),
    );
    expect(d.activateCategoryId, isNull);
    expect(d.newState.autoCategoryId, isNull);
  });

  test('ما يعيد تفعيل المكان غصب لو المستخدم غيّره وهو باقي فيه', () {
    final d = decide(
      [cat('default', active: true), cat('masjid', at: mosque)],
      mosque,
      const LocationSwitchState(autoCategoryId: 'masjid'),
    );
    expect(d.activateCategoryId, isNull);
    expect(d.newState.autoCategoryId, 'masjid');
  });

  test('ما يتذبذب على حدود المكان (هامش ٥٠م)', () {
    // نطاق ١٢٠م والمسافة ~١٥٦م: برا النطاق بس داخل الهامش (١٢٠+٥٠=١٧٠م)
    final d = decide(
      [cat('default'), cat('masjid', active: true, at: home, radius: 120)],
      mosque,
      const LocationSwitchState(
        autoCategoryId: 'masjid',
        previousCategoryId: 'default',
      ),
    );
    expect(d.activateCategoryId, isNull);
    expect(d.newState.autoCategoryId, 'masjid');
  });

  test('لو طلع من مكان ودخل مكان ثاني يفعّل الثاني ويحتفظ بالأصلية', () {
    final d = decide(
      [
        cat('default'),
        cat('home', active: true, at: home, radius: 50),
        cat('masjid', at: mosque, radius: 50),
      ],
      mosque,
      const LocationSwitchState(
        autoCategoryId: 'home',
        previousCategoryId: 'default',
      ),
    );
    expect(d.activateCategoryId, 'masjid');
    expect(d.newState.autoCategoryId, 'masjid');
    expect(d.newState.previousCategoryId, 'default');
  });

  test('يختار الأقرب لو كان داخل مكانين', () {
    final d = decide([
      cat('default', active: true),
      cat('home', at: home, radius: 500),
      cat('masjid', at: mosque, radius: 500),
    ], mosque);
    expect(d.activateCategoryId, 'masjid');
  });

  test('لو المجموعة المفعّلة تلقائيًا انحذفت ينظّف الحالة بدون أخطاء', () {
    final d = decide(
      [cat('default', active: true)],
      mosque,
      const LocationSwitchState(
        autoCategoryId: 'deleted',
        previousCategoryId: 'default',
      ),
    );
    expect(d.activateCategoryId, isNull);
    expect(d.newState.autoCategoryId, isNull);
  });

  test('ما يسوي شي لو المجموعة أصلاً مفعّلة وهو في مكانها', () {
    final d = decide([
      cat('default'),
      cat('masjid', active: true, at: mosque),
    ], mosque);
    expect(d.activateCategoryId, isNull);
    expect(d.newState.autoCategoryId, isNull);
  });

  test('القيم القديمة بدون موقع تنقرا عادي', () {
    expect(LocationTriggerModel.fromMap(null), isNull);
    expect(LocationTriggerModel.fromMap({'isEnabled': true}), isNull);
    final t = LocationTriggerModel.fromMap({
      'isEnabled': true,
      'latitude': 24,
      'longitude': 46,
    });
    expect(t!.radiusMeters, LocationTriggerModel.defaultRadiusMeters);
  });

  test('تشغيل استماع جديد يلغي الاختيار اليدوي القديم ويفعّل المكان', () {
    final d = decideLocationSwitch(
      categories: [
        cat('default', active: true),
        cat('masjid', at: mosque),
      ],
      latitude: mosque.$1,
      longitude: mosque.$2,
      state: const LocationSwitchState(autoCategoryId: 'masjid'),
      isNewListeningSession: true,
    );
    expect(d.activateCategoryId, 'masjid');
    expect(d.newState.previousCategoryId, 'default');
  });

  test('تشغيل استماع جديد ما يخرّب الحالة لو المجموعة التلقائية مفعّلة', () {
    final d = decideLocationSwitch(
      categories: [
        cat('default'),
        cat('masjid', active: true, at: mosque),
      ],
      latitude: mosque.$1,
      longitude: mosque.$2,
      state: const LocationSwitchState(
        autoCategoryId: 'masjid',
        previousCategoryId: 'default',
      ),
      isNewListeningSession: true,
    );
    expect(d.activateCategoryId, isNull);
    expect(d.newState.previousCategoryId, 'default');
  });
}
