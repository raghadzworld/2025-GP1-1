import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_tap_handler.dart';

/// أول تنبيه لشحن الساعة.
const int kWatchLowBatteryPercent = 20;

/// تنبيه ثاني أوضح لما الشحن ينزل أكثر.
const int kWatchCriticalBatteryPercent = 10;

/// ما نرجّع نجهّز التنبيهات إلا لما الشحن يرتفع لهذي النسبة — عشان التذبذب
/// حول ٢٠٪ (١٩ ← ٢١ ← ٢٠) ما يطلّع نفس التنبيه كل شوي.
const int kWatchBatteryRearmPercent = 25;

/// مرحلة الشحن المنخفض: none (فوق ٢٠٪)، low (٢٠٪ وأقل)، critical (١٠٪ وأقل).
enum BatteryLevel { none, low, critical }

/// المرحلة اللي توصف النسبة الحالية — للبانر داخل التطبيق.
BatteryLevel batteryLevelFor(int batteryPercent) {
  if (batteryPercent < 0) return BatteryLevel.none; // غير متوفرة
  if (batteryPercent <= kWatchCriticalBatteryPercent) {
    return BatteryLevel.critical;
  }
  if (batteryPercent <= kWatchLowBatteryPercent) return BatteryLevel.low;
  return BatteryLevel.none;
}

class BatteryAlertDecision {
  /// المرحلة اللي ننبّه عليها الحين (null = لا تنبّه)
  final BatteryLevel? alert;

  /// أعلى مرحلة نبّهنا عليها بعد هذي القراءة
  final BatteryLevel alerted;

  const BatteryAlertDecision(this.alert, this.alerted);
}

/// منطق القرار بحد ذاته — بدون إشعارات ولا تخزين عشان نقدر نختبره.
/// كل مرحلة تنبّه مرة وحدة، وما يرجع شي إلا بعد الشحن لـ ٢٥٪.
BatteryAlertDecision decideBatteryAlert({
  required int batteryPercent,
  required BatteryLevel alreadyAlerted,
}) {
  if (batteryPercent < 0) {
    return BatteryAlertDecision(null, alreadyAlerted);
  }
  if (batteryPercent >= kWatchBatteryRearmPercent) {
    return const BatteryAlertDecision(null, BatteryLevel.none);
  }
  final level = batteryLevelFor(batteryPercent);
  if (level.index > alreadyAlerted.index) {
    return BatteryAlertDecision(level, level);
  }
  return BatteryAlertDecision(null, alreadyAlerted);
}

/// إشعار بالجوال لما شحن الساعة يوصل ٢٠٪ ثم ١٠٪. يُستدعى مع كل حالة توصل
/// من الساعة (كل ٥ ثواني تقريبًا). أي عزلة ممكن تكون مالكة الاتصال (الواجهة
/// أو خدمة الاستماع)، فالمرحلة اللي نبّهنا عليها محفوظة بـ
/// SharedPreferencesAsync (بدون كاش) عشان الاثنين يشوفون نفس القيمة.
class WatchBatteryAlert {
  static const _kAlertedKey = 'watch_low_battery_level';
  static const _kChannelId = 'nabeeh_watch_battery_channel';
  static const _kNotificationId = 8920;
  // أيقونة بيضاء بلون واحد — أندرويد يحوّل أيقونة التطبيق الملوّنة لمربع فاضي
  static const _kIcon = '@drawable/ic_stat_nabeeh';
  static const _kLargeIcon = 'ic_notification_large';

  static bool _checking = false;
  static bool _notificationsReady = false;
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> onBatteryReading(int batteryPercent) async {
    if (_checking) return;
    _checking = true;
    try {
      final prefs = SharedPreferencesAsync();
      final stored = await prefs.getInt(_kAlertedKey) ?? 0;
      final alreadyAlerted = BatteryLevel
          .values[stored.clamp(0, BatteryLevel.values.length - 1)];
      final decision = decideBatteryAlert(
        batteryPercent: batteryPercent,
        alreadyAlerted: alreadyAlerted,
      );
      if (decision.alerted != alreadyAlerted) {
        await prefs.setInt(_kAlertedKey, decision.alerted.index);
      }
      if (decision.alert != null) {
        await _show(batteryPercent, decision.alert!);
        debugPrint(
          'WatchBatteryAlert: ${decision.alert!.name} ($batteryPercent%)',
        );
      } else if (decision.alerted == BatteryLevel.none &&
          alreadyAlerted != BatteryLevel.none) {
        await _cancel();
        debugPrint('WatchBatteryAlert: re-armed ($batteryPercent%)');
      }
    } catch (e) {
      debugPrint('WatchBatteryAlert: failed — $e');
    } finally {
      _checking = false;
    }
  }

  static Future<void> _ensureNotifications() async {
    if (_notificationsReady) return;
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_kIcon),
      ),
      onDidReceiveNotificationResponse: onNabeehNotificationTap,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _kChannelId,
            'بطارية الساعة',
            description: 'تنبيه لما شحن الساعة يصير منخفض',
            importance: Importance.high,
          ),
        );
    _notificationsReady = true;
  }

  static Future<void> _show(int batteryPercent, BatteryLevel level) async {
    await _ensureNotifications();
    final critical = level == BatteryLevel.critical;
    final body = 'المتبقي $batteryPercent٪ فقط';
    await _notifications.show(
      id: _kNotificationId,
      // 🔋 أخضر عند ٢٠٪، 🪫 أحمر عند ١٠٪
      title: critical ? '🪫 الساعة تحتاج شحن' : '🔋 الساعة تحتاج شحن',
      body: body,
      // الضغط عليه يفتح تبويب الساعة (فيه البطارية)
      payload: kWatchBatteryPayload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          'بطارية الساعة',
          channelDescription: 'تنبيه لما شحن الساعة يصير منخفض',
          importance: Importance.high,
          priority: Priority.high,
          icon: _kIcon,
          // نفس شكل أيقونة التطبيق: الدائرة الصغيرة كحلي (أندرويد يفرض أيقونة
          // صغيرة بلون واحد)، وأيقونة التطبيق الكاملة كصورة كبيرة — ثابتة
          // بالمرحلتين، والفرق بينهم بلون الإيموجي بالعنوان بس.
          color: const Color(0xFF21277B),
          largeIcon: const DrawableResourceAndroidBitmap(_kLargeIcon),
          // قابل للتوسيع: يبين اسم التطبيق (نبيه) فوق
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  static Future<void> _cancel() async {
    await _ensureNotifications();
    await _notifications.cancel(id: _kNotificationId);
  }
}
