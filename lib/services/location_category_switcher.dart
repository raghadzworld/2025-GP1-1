import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/categories/data/models/category_model.dart';
import '../features/categories/data/services/category_service.dart';

/// مسافة إضافية فوق نطاق المكان قبل ما نعتبر المستخدم طلع منه — عشان دقة
/// الـ GPS المتذبذبة على الحدود ما تخلي المجموعة تتبدّل وترجع كل شوي.
const double kLocationExitMarginMeters = 50;

/// المجموعة اللي فعّلناها تلقائيًا بسبب الموقع، والمجموعة اللي كانت شغالة
/// قبلها (عشان نرجّعها لما المستخدم يطلع من المكان).
class LocationSwitchState {
  final String? autoCategoryId;
  final String? previousCategoryId;

  const LocationSwitchState({this.autoCategoryId, this.previousCategoryId});

  static const empty = LocationSwitchState();
}

class LocationSwitchDecision {
  /// المجموعة اللي لازم تتفعّل الحين (null = لا تغيّر شي)
  final String? activateCategoryId;
  final LocationSwitchState newState;

  const LocationSwitchDecision({
    required this.activateCategoryId,
    required this.newState,
  });
}

typedef DistanceFn =
    double Function(double lat1, double lng1, double lat2, double lng2);

/// منطق القرار بحد ذاته — بدون GPS ولا Firebase عشان نقدر نختبره.
LocationSwitchDecision decideLocationSwitch({
  required List<CategoryModel> categories,
  required double latitude,
  required double longitude,
  required LocationSwitchState state,
  bool isNewListeningSession = false,
  DistanceFn distance = Geolocator.distanceBetween,
}) {
  CategoryModel? byId(String? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  double? distanceTo(CategoryModel c) {
    final t = c.locationTrigger;
    if (t == null || !t.isEnabled) return null;
    return distance(latitude, longitude, t.latitude, t.longitude);
  }

  String? activeId;
  for (final c in categories) {
    if (c.isEnabled) {
      activeId = c.id;
      break;
    }
  }

  // اختيار المستخدم اليدوي (غيّر المجموعة وهو داخل المكان) يدوم لين نهاية
  // جلسة الاستماع بس — مع كل تشغيل جديد للاستماع نقيّم المكان من جديد.
  if (isNewListeningSession && state.autoCategoryId != null) {
    final auto = byId(state.autoCategoryId);
    if (auto == null || !auto.isEnabled) state = LocationSwitchState.empty;
  }

  // ١) فيه مجموعة فعّلناها قبل بسبب الموقع؟
  if (state.autoCategoryId != null) {
    final auto = byId(state.autoCategoryId);
    final d = auto == null ? null : distanceTo(auto);
    final stillInside =
        d != null &&
        d <= auto!.locationTrigger!.radiusMeters + kLocationExitMarginMeters;

    if (stillInside) {
      // باقي في المكان — حتى لو المستخدم غيّر المجموعة بيده، نحترم اختياره
      // وما نرجّعها غصب عليه.
      return LocationSwitchDecision(activateCategoryId: null, newState: state);
    }

    // طلع من المكان (أو المجموعة انحذفت / انطفى موقعها)
    String? restoreId;
    if (auto != null && auto.isEnabled) {
      final previous = byId(state.previousCategoryId);
      if (previous != null && previous.id != auto.id) restoreId = previous.id;
    }
    if (restoreId != null) activeId = restoreId;

    // يمكن طلع من مكان ودخل مكان ثاني بنفس اللحظة
    final next = _nearestInside(categories, distanceTo);
    if (next != null && next.id != activeId) {
      return LocationSwitchDecision(
        activateCategoryId: next.id,
        newState: LocationSwitchState(
          autoCategoryId: next.id,
          previousCategoryId: activeId,
        ),
      );
    }
    return LocationSwitchDecision(
      activateCategoryId: restoreId,
      newState: LocationSwitchState.empty,
    );
  }

  // ٢) ما فيه تفعيل تلقائي سابق — هل وصل لمكان مجموعة؟
  final next = _nearestInside(categories, distanceTo);
  if (next == null || next.id == activeId) {
    return const LocationSwitchDecision(
      activateCategoryId: null,
      newState: LocationSwitchState.empty,
    );
  }
  return LocationSwitchDecision(
    activateCategoryId: next.id,
    newState: LocationSwitchState(
      autoCategoryId: next.id,
      previousCategoryId: activeId,
    ),
  );
}

CategoryModel? _nearestInside(
  List<CategoryModel> categories,
  double? Function(CategoryModel) distanceTo,
) {
  CategoryModel? best;
  double? bestDistance;
  for (final c in categories) {
    final d = distanceTo(c);
    if (d == null || d > c.locationTrigger!.radiusMeters) continue;
    if (bestDistance == null || d < bestDistance) {
      best = c;
      bestDistance = d;
    }
  }
  return best;
}

/// يجيب الموقع الحالي ويفعّل المجموعة المناسبة. يشتغل من خدمة الاستماع
/// (isolate منفصل) ومن واجهة التطبيق، فالحالة محفوظة بـ SharedPreferencesAsync
/// (بدون كاش) عشان الاثنين يشوفون نفس القيمة.
class LocationCategorySwitcher {
  static const _kAutoKey = 'location_auto_category_id';
  static const _kPreviousKey = 'location_previous_category_id';

  /// صلاحية الموقع موجودة؟ (بدون ما نطلبها — الطلب يصير من شاشة المجموعة)
  static Future<bool> hasPermission() async {
    try {
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.whileInUse ||
          p == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  /// يرجّع المجموعة اللي تفعّلت (أو null لو ما تغيّر شي).
  static Future<CategoryModel?> checkAndSwitch(
    CategoryService service, {
    bool isNewListeningSession = false,
  }) async {
    try {
      final categories = await service.getCategories();
      final hasTriggers = categories.any(
        (c) => c.locationTrigger?.isEnabled ?? false,
      );

      final prefs = SharedPreferencesAsync();
      final state = LocationSwitchState(
        autoCategoryId: await prefs.getString(_kAutoKey),
        previousCategoryId: await prefs.getString(_kPreviousKey),
      );
      if (!hasTriggers && state.autoCategoryId == null) {
        debugPrint('LocationSwitch: no categories use location — skipped');
        return null;
      }
      if (!await hasPermission()) {
        debugPrint('LocationSwitch: location permission not granted — skipped');
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('LocationSwitch: GPS is off — skipped');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final decision = decideLocationSwitch(
        categories: categories,
        latitude: position.latitude,
        longitude: position.longitude,
        state: state,
        isNewListeningSession: isNewListeningSession,
      );

      final toActivate = decision.activateCategoryId;
      debugPrint(
        'LocationSwitch: at ${position.latitude.toStringAsFixed(5)},'
        '${position.longitude.toStringAsFixed(5)} '
        '(±${position.accuracy.round()}m) → '
        '${toActivate == null ? 'no change' : 'activate $toActivate'} '
        '[auto=${decision.newState.autoCategoryId}, '
        'prev=${decision.newState.previousCategoryId}]',
      );
      if (toActivate != null) {
        await service.setActiveCategory(
          toActivate,
          currentCategories: categories,
        );
      }
      await _saveState(prefs, decision.newState);

      if (toActivate == null) return null;
      return categories
          .firstWhere((c) => c.id == toActivate)
          .copyWith(isEnabled: true);
    } catch (e) {
      // فشل الـ GPS أو الشبكة — نحاول بالدورة الجاية
      debugPrint('LocationSwitch: check failed — $e');
      return null;
    }
  }

  /// لما المستخدم يفعّل مجموعة بيده: نبقي المكان محفوظ (عشان ما نعيد تفعيل
  /// مجموعته غصب عليه وهو باقي فيه) بس ننسى المجموعة السابقة، عشان ما
  /// نرجّعها فوق اختياره لما يطلع.
  static Future<void> onManualActivation() async {
    try {
      final prefs = SharedPreferencesAsync();
      final autoId = await prefs.getString(_kAutoKey);
      if (autoId == null) return;
      await _saveState(prefs, LocationSwitchState(autoCategoryId: autoId));
    } catch (_) {}
  }

  static Future<void> _saveState(
    SharedPreferencesAsync prefs,
    LocationSwitchState state,
  ) async {
    if (state.autoCategoryId == null) {
      await prefs.remove(_kAutoKey);
    } else {
      await prefs.setString(_kAutoKey, state.autoCategoryId!);
    }
    if (state.previousCategoryId == null) {
      await prefs.remove(_kPreviousKey);
    } else {
      await prefs.setString(_kPreviousKey, state.previousCategoryId!);
    }
  }
}
