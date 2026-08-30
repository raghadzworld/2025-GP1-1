import 'dart:async';
import 'dart:convert';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'watch_audio_socket.dart';

/// جدولة "منبّهات" حقيقية على مستوى نظام أندرويد (AlarmManager) — تشتغل حتى
/// لو المستخدم أغلق التطبيق بالكامل (سحبه من الخلفية)، على عكس أي مؤقّت
/// داخل التطبيق نفسه اللي يموت لحظة إغلاقه. عند وصول وقت المنبّه: يظهر
/// إشعار على الجوال، ويحاول (لو عنوان الساعة معروف) إرسال نفس كود الاهتزاز
/// اللي تستخدمه أكواد اكتشاف الصوت (#code+pattern+intensity) عشان تهتز الساعة.
///
/// أندرويد فقط حاليًا — AlarmManager نظام أندرويد بحت، و iOS ما يسمح أصلًا
/// بتنفيذ كود عشوائي بالخلفية بدقّة وقت مضبوطة بنفس الطريقة.
const kReminderNotificationChannelId = 'nabeeh_reminder_channel';
const _kReminderMetaPrefsPrefix = 'reminder_alarm_meta_';

// DateTime.weekday: Monday=1 ... Sunday=7 — نفس ترتيب الأيام المستخدم في
// add_reminder_screen.dart (لازم يضل مطابق له).
const Map<String, int> _kDayNameToWeekday = {
  'الأحد': 7,
  'الاثنين': 1,
  'الثلاثاء': 2,
  'الأربعاء': 3,
  'الخميس': 4,
  'الجمعة': 5,
  'السبت': 6,
};

/// هاش بسيط وثابت (FNV-1a) بدل الاعتماد على String.hashCode المدمج — غير
/// موثّق رسميًا إنه يضل ثابت بين إصدارات Dart، وهذا المعرّف لازم يضل نفسه
/// دايمًا عشان جدولة/إلغاء نفس التذكير (بمعرّف Firestore نفسه) يشتغل على
/// نفس رقم إنذار AlarmManager دايمًا.
int reminderAlarmId(String reminderId) {
  var hash = 0x811c9dc5;
  for (final unit in reminderId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7fffffff;
}

DateTime _nextOccurrence(int hour24, int minute, List<String> daysActive) {
  final now = DateTime.now();
  var candidate = DateTime(now.year, now.month, now.day, hour24, minute);

  final targetWeekdays = daysActive
      .map((d) => _kDayNameToWeekday[d])
      .whereType<int>()
      .toSet();

  if (targetWeekdays.isEmpty) {
    // منبّه "مرة وحدة" (أو بيانات أيام غير متوقعة) — أقرب وقت مطابق قادم،
    // اليوم لو لسا ما فات، وإلا باكر.
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  for (var i = 0; i < 8; i++) {
    if (targetWeekdays.contains(candidate.weekday) && candidate.isAfter(now)) {
      return candidate;
    }
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate; // احتياطي، ما يوصله عمليًا (٧ أيام تكفي لتغطية أي أسبوع)
}

Future<void> _scheduleAlarmFromMeta(int id, Map<String, dynamic> meta) async {
  final hour24 = meta['hour24'] as int;
  final minute = meta['minute'] as int;
  final daysActive = List<String>.from(meta['daysActive'] as List? ?? const []);
  final nextFire = _nextOccurrence(hour24, minute, daysActive);

  await AndroidAlarmManager.oneShotAt(
    nextFire,
    id,
    reminderAlarmCallback,
    exact: true,
    wakeup: true,
    rescheduleOnReboot: true,
    alarmClock: true, // أدق أنواع الجدولة على أندرويد وأقلها عرضة للتأجيل بتوفير الطاقة
  );
}

class ReminderAlarmService {
  static Future<void> initialize() async {
    await AndroidAlarmManager.initialize();

    // "جدولة إنذار دقيق" على أندرويد ١٣+ صلاحية خاصة ما تُمنح تلقائيًا ولا
    // عن طريق نافذة الأذونات المعتادة — لازم المستخدم يوافق عليها من
    // إعدادات النظام مباشرة. طلبها هنا (مرة عند بدء التطبيق) يفتح تلك
    // الشاشة أول مرة بدل ما تُكتشف المشكلة بصمت لما منبّه ما يشتغل بوقته.
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  /// يحسب أقرب وقت قادم يطابق (الساعة/الدقيقة + الأيام المختارة)، ويجدول
  /// إنذار أندرويد حقيقي عنده. بديل عن "كرّر أسبوعيًا" غير المتوفر مباشرة
  /// بـ AlarmManager: كل تنفيذ يعيد جدولة نفسه للمرة الجاية (انظر
  /// reminderAlarmCallback). لو daysActive فاضية، يُعتبر "مرة وحدة".
  static Future<void> scheduleReminder({
    required String reminderId,
    required String label,
    required int hour24,
    required int minute,
    required List<String> daysActive,
    required int vibrationPattern,
    required int vibrationPower,
  }) async {
    final id = reminderAlarmId(reminderId);
    final meta = {
      'label': label,
      'hour24': hour24,
      'minute': minute,
      'daysActive': daysActive,
      'vibrationPattern': vibrationPattern,
      'vibrationPower': vibrationPower,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kReminderMetaPrefsPrefix$id', jsonEncode(meta));
    await _scheduleAlarmFromMeta(id, meta);
  }

  static Future<void> cancelReminder(String reminderId) async {
    final id = reminderAlarmId(reminderId);
    await AndroidAlarmManager.cancel(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kReminderMetaPrefsPrefix$id');
  }
}

// يحتاج @pragma('vm:entry-point') لأن AlarmManager يستدعيه من عزلة (isolate)
// خلفية جديدة تمامًا — بدون هذا الـ pragma ممكن الـ tree shaking وقت البناء
// يشيله لأنه ما يشوف أي استدعاء مباشر له من main()/التطبيق نفسه.
@pragma('vm:entry-point')
Future<void> reminderAlarmCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final rawMeta = prefs.getString('$_kReminderMetaPrefsPrefix$id');
  if (rawMeta == null) return; // تم إلغاء هذا التذكير بعد ما جُدول الإنذار

  final meta = jsonDecode(rawMeta) as Map<String, dynamic>;
  final label = meta['label'] as String? ?? 'تذكير';
  final daysActive = List<String>.from(meta['daysActive'] as List? ?? const []);
  final vibrationPattern = meta['vibrationPattern'] as int? ?? 1;
  final vibrationPower = meta['vibrationPower'] as int? ?? 2;

  await _showReminderNotification(label);

  final watchIp = prefs.getString(kWatchIpPrefsKey);
  if (watchIp != null && watchIp.isNotEmpty) {
    // الفيرموير يفهم فقط أرقام أنماط اهتزاز '1'-'3' — التطبيق يعرض خيار
    // رابع للمنبّهات ("تصاعدي") ما له مقابل بالساعة، فنحصره بأقصى ٣ قبل
    // التحويل. نفس معادلة التحويل المستخدمة لأكواد اكتشاف الصوت الحالية.
    final clampedPattern = vibrationPattern.clamp(1, 3);
    final clampedPower = vibrationPower.clamp(1, 3);
    await WatchAudioSocket.sendCodeToHostDirect(
      watchIp,
      'T', // تذكير — انظر main.cpp: result_codes[]
      pattern: 4 - clampedPattern,
      power: 4 - clampedPower,
    );
  }

  // منبّه متكرر (فيه أيام محددة): جدول التنفيذ الجاي فورًا بنفس البيانات
  // المحفوظة. منبّه "مرة وحدة" (daysActive فاضية) انتهى غرضه، نمسح بياناته.
  if (daysActive.isNotEmpty) {
    await _scheduleAlarmFromMeta(id, meta);
  } else {
    await prefs.remove('$_kReminderMetaPrefsPrefix$id');
  }
}

Future<void> _showReminderNotification(String label) async {
  final notifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(
    settings: const InitializationSettings(android: androidInit),
  );

  const channel = AndroidNotificationChannel(
    kReminderNotificationChannelId,
    'تذكيرات نبيه',
    description: 'إشعار عند وصول وقت أحد التذكيرات',
    importance: Importance.max,
  );
  await notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await notifications.show(
    id: label.hashCode & 0x7fffffff,
    title: 'تذكير',
    body: label,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        kReminderNotificationChannelId,
        'تذكيرات نبيه',
        channelDescription: 'إشعار عند وصول وقت أحد التذكيرات',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
      ),
    ),
  );
}
