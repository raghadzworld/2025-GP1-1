import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نسبة شحن الساعة اللي ننبّه عندها.
const int kWatchLowBatteryPercent = 20;

/// ما نرجّع نجهّز التنبيه إلا لما الشحن يرتفع لهذي النسبة — عشان التذبذب
/// حول ٢٠٪ (١٩ ← ٢١ ← ٢٠) ما يطلّع نفس التنبيه كل شوي.
const int kWatchBatteryRearmPercent = 25;

enum BatteryAlertAction { none, alert, rearm }

/// منطق القرار بحد ذاته — بدون إشعارات ولا تخزين عشان نقدر نختبره.
BatteryAlertAction decideBatteryAlert({
  required int batteryPercent,
  required bool alreadyAlerted,
}) {
  if (batteryPercent < 0) return BatteryAlertAction.none; // غير متوفرة
  if (!alreadyAlerted && batteryPercent <= kWatchLowBatteryPercent) {
    return BatteryAlertAction.alert;
  }
  if (alreadyAlerted && batteryPercent >= kWatchBatteryRearmPercent) {
    return BatteryAlertAction.rearm;
  }
  return BatteryAlertAction.none;
}

/// إشعار بالجوال لما شحن الساعة يوصل ٢٠٪. يُستدعى مع كل حالة توصل من
/// الساعة (كل ٥ ثواني تقريبًا). أي عزلة ممكن تكون مالكة الاتصال (الواجهة أو
/// خدمة الاستماع)، فحالة "نبّهنا" محفوظة بـ SharedPreferencesAsync (بدون
/// كاش) عشان الاثنين يشوفون نفس القيمة وما يتكرر الإشعار.
class WatchBatteryAlert {
  static const _kAlertedKey = 'watch_low_battery_alerted';
  static const _kChannelId = 'nabeeh_watch_battery_channel';
  static const _kNotificationId = 8920;

  static bool _checking = false;
  static bool _notificationsReady = false;
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> onBatteryReading(int batteryPercent) async {
    if (_checking) return;
    _checking = true;
    try {
      final prefs = SharedPreferencesAsync();
      final alerted = await prefs.getBool(_kAlertedKey) ?? false;
      switch (decideBatteryAlert(
        batteryPercent: batteryPercent,
        alreadyAlerted: alerted,
      )) {
        case BatteryAlertAction.alert:
          await prefs.setBool(_kAlertedKey, true);
          await _show(batteryPercent);
          debugPrint('WatchBatteryAlert: low battery ($batteryPercent%)');
        case BatteryAlertAction.rearm:
          await prefs.setBool(_kAlertedKey, false);
          await _cancel();
          debugPrint('WatchBatteryAlert: re-armed ($batteryPercent%)');
        case BatteryAlertAction.none:
          break;
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
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
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

  static Future<void> _show(int batteryPercent) async {
    await _ensureNotifications();
    await _notifications.show(
      id: _kNotificationId,
      title: '🔋 شحن الساعة منخفض',
      body: 'شحن الساعة $batteryPercent٪ — اشحنيها عشان ما تفوتك التنبيهات',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          'بطارية الساعة',
          channelDescription: 'تنبيه لما شحن الساعة يصير منخفض',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> _cancel() async {
    await _ensureNotifications();
    await _notifications.cancel(id: _kNotificationId);
  }
}
