import 'dart:async';
import 'dart:convert';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'watch_audio_socket.dart';

/// جدولة تذكيرات تشتغل حتى لو التطبيق مقفول بالكامل.
///
/// الطريقة: الإشعار نفسه يُجدول عبر flutter_local_notifications
/// (zonedSchedule)، يعني أندرويد يسجّل الموعد ويطلق الإشعار من مُستقبِل
/// أصلي (Java) مصرَّح عنه بالمانيفست — بدون ما يحتاج يشغّل أي كود Dart ولا
/// يفتح عزلة خلفية وقت الموعد. والتكرار الأسبوعي أصلي كمان
/// (matchDateTimeComponents)، فما فيه شي لازم "يعيد جدولة نفسه".
///
/// هذا مقصود: النسخة السابقة كانت تعتمد على AlarmManager عشان يشغّل دالة
/// Dart بعزلة خلفية، والعزلة هذي هشّة — الحزمة تناديها بدون await فتنهدم
/// وسط التنفيذ، وتتزاحم مع العزلة الخلفية الثانية بالتطبيق
/// (flutter_background_service)، وأنظمة مثل HyperOS تقتلها بسهولة. النتيجة
/// كانت: أول تذكير يشتغل وبعدين تسكت التذكيرات لين يُفتح التطبيق من جديد.
///
/// AlarmManager ما زال مستخدمًا لغرض واحد ثانوي فقط: إرسال كود الاهتزاز
/// للساعة وقت التذكير (يحتاج كود Dart، ما فيه بديل أصلي). لو فشل هذا الجزء
/// ما يضر — إشعار الجوال (واهتزازه) مستقل عنه تمامًا.
const kReminderNotificationChannelId = 'nabeeh_reminder_channel';
const _kReminderMetaPrefsPrefix = 'reminder_alarm_meta_';

/// المنطقة الزمنية المستخدمة بالجدولة. مثبّتة لأن نبيه تطبيق عربي موجّه
/// للسعودية (ما فيها توقيت صيفي، فالإزاحة ثابتة دائمًا). لو صار التطبيق
/// يُستخدم خارجها، تُستبدل بقراءة منطقة الجهاز عبر حزمة flutter_timezone.
const _kAppTimeZone = 'Asia/Riyadh';

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

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _kReminderChannel = AndroidNotificationChannel(
  kReminderNotificationChannelId,
  'تذكيرات نبيه',
  description: 'إشعار عند وصول وقت أحد التذكيرات',
  importance: Importance.max,
);

const NotificationDetails _kReminderDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    kReminderNotificationChannelId,
    'تذكيرات نبيه',
    channelDescription: 'إشعار عند وصول وقت أحد التذكيرات',
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
  ),
);

/// هاش بسيط وثابت (FNV-1a) بدل الاعتماد على String.hashCode المدمج — غير
/// موثّق رسميًا إنه يضل ثابت بين إصدارات Dart، وهذا المعرّف لازم يضل نفسه
/// دايمًا عشان جدولة/إلغاء نفس التذكير (بمعرّف Firestore نفسه) تشتغل على
/// نفس الأرقام دايمًا.
///
/// النتيجة دايمًا من مضاعفات ٨: كل تذكير يحجز ٨ أرقام متتالية —
/// base+1..base+7 لكل يوم من أيام الأسبوع (التكرار الأسبوعي يحتاج إشعارًا
/// مجدولًا مستقلًا لكل يوم)، و base+0 للتذكير غير المتكرر.
int reminderAlarmId(String reminderId) {
  var hash = 0x811c9dc5;
  for (final unit in reminderId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFF8;
}

Set<int> _weekdaysOf(List<String> daysActive) =>
    daysActive.map((d) => _kDayNameToWeekday[d]).whereType<int>().toSet();

/// أقرب لحظة قادمة توافق الساعة/الدقيقة المطلوبة — ولو حُدّد weekday، توافق
/// ذاك اليوم من الأسبوع كمان. الحلقة محدودة بـ٨ دورات عشان ما تصير حلقة لا
/// نهائية لو وصلها يوم غير صالح.
tz.TZDateTime _nextInstanceOf(int hour24, int minute, {int? weekday}) {
  final now = tz.TZDateTime.now(tz.local);
  // هامش بسيط: ما نجدول لحظة قد تكون فاتت للتو.
  final earliest = now.add(const Duration(seconds: 5));
  var scheduled = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    hour24,
    minute,
  );

  var guard = 0;
  while (guard++ < 8 &&
      (!scheduled.isAfter(earliest) ||
          (weekday != null && scheduled.weekday != weekday))) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}

/// يجدول إشعارًا واحدًا. يحاول أولًا بوضع "منبّه" (setAlarmClock) — أقوى ما
/// يوفّره أندرويد: يتجاوز وضع توفير الطاقة ويظهر أيقونة المنبّه بشريط
/// الحالة. لو كانت صلاحية الإنذار الدقيق مرفوضة يرمي النظام استثناء، فنرجع
/// لجدولة تقريبية بدل ما يضيع التذكير كليًا.
Future<void> _scheduleOne({
  required int id,
  required String label,
  required tz.TZDateTime at,
  DateTimeComponents? matchDateTimeComponents,
}) async {
  Future<void> attempt(AndroidScheduleMode mode) => _notifications.zonedSchedule(
    id: id,
    title: 'تذكير',
    body: label,
    scheduledDate: at,
    notificationDetails: _kReminderDetails,
    androidScheduleMode: mode,
    matchDateTimeComponents: matchDateTimeComponents,
  );

  try {
    await attempt(AndroidScheduleMode.alarmClock);
  } on PlatformException catch (e) {
    debugPrint('_scheduleOne($id): exact alarm refused (${e.code}) — inexact');
    await attempt(AndroidScheduleMode.inexactAllowWhileIdle);
  }
}

/// يجدول كل إشعارات تذكير واحد. يرجّع موعد التذكير غير المتكرر (أو null لو
/// كان متكررًا) عشان نقدر نعرف لاحقًا إن التذكير غير المتكرر انتهى.
Future<tz.TZDateTime?> _scheduleReminderNotifications({
  required int base,
  required String label,
  required int hour24,
  required int minute,
  required Set<int> weekdays,
}) async {
  if (weekdays.isEmpty) {
    final at = _nextInstanceOf(hour24, minute);
    await _scheduleOne(id: base, label: label, at: at);
    return at;
  }

  for (final weekday in weekdays) {
    await _scheduleOne(
      id: base + weekday,
      label: label,
      at: _nextInstanceOf(hour24, minute, weekday: weekday),
      // التكرار الأسبوعي يتكفّل فيه النظام: نفس اليوم ونفس الوقت، كل أسبوع،
      // بدون أي كود Dart وقت الموعد.
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
  return null;
}

/// يجدول تنبيه الساعة (اهتزاز السوار) لأقرب موعد قادم للتذكير. "أفضل جهد"
/// فقط — إشعار الجوال ما يعتمد عليه إطلاقًا.
Future<void> _scheduleWatchPing(int base, Map<String, dynamic> meta) async {
  try {
    final hour24 = meta['hour24'] as int;
    final minute = meta['minute'] as int;
    final weekdays = _weekdaysOf(
      List<String>.from(meta['daysActive'] as List? ?? const []),
    );

    final next = weekdays.isEmpty
        ? _nextInstanceOf(hour24, minute)
        : weekdays
              .map((w) => _nextInstanceOf(hour24, minute, weekday: w))
              .reduce((a, b) => a.isBefore(b) ? a : b);

    await AndroidAlarmManager.oneShotAt(
      DateTime.fromMillisecondsSinceEpoch(next.millisecondsSinceEpoch),
      base,
      reminderAlarmCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  } catch (e) {
    debugPrint('_scheduleWatchPing($base): $e');
  }
}

/// أقصى عدد تذكيرات تخزّنه الساعة (MAX_WATCH_REMINDERS بالفيرموير) — نقص
/// الزيادة هنا بدل ما نرسل جدولًا تتجاهل الساعة آخره بصمت.
const _kMaxWatchReminders = 16;

/// ينظّف اسم التذكير قبل ما يُرسل للساعة:
/// - ';' والأسطر الجديدة محجوزة كفواصل بالبروتوكول، فنبدّلها بمسافة. (':'
///   مسموح لأن الاسم آخر حقل بالمقطع، فما فيه لبس.)
/// - خط الساعة مولّد للمدى ‎0x20-0x7E‎ و ‎0x600-0x6FF‎ فقط — أي حرف خارجه
///   (إيموجي مثلًا) يطلع مربعًا فاضيًا، فنشيله بدل ما يظهر مشوّهًا.
/// - القص حسب طول UTF-8 مو عدد الأحرف: مخزن الساعة ٦٤ بايت، فنوقف عند ٤٧
///   بهامش مريح، وعلى حدود حرف كامل عشان ما يوصلها نصف حرف.
String sanitizeWatchLabel(String raw) {
  var cleaned = raw
      .replaceAll(RegExp(r'[;\r\n]'), ' ')
      .replaceAll(RegExp(r'[^\u0020-\u007E\u0600-\u06FF]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  const maxBytes = 47;
  while (cleaned.isNotEmpty && utf8.encode(cleaned).length > maxBytes) {
    cleaned = cleaned.substring(0, cleaned.length - 1);
  }
  return cleaned.trim();
}

/// يبني نص الجدول اللي تفهمه الساعة:
///   H:M:daysMask:pattern:intensity:once:label   ومقاطعه مفصولة بـ ';'
/// الاسم آخر حقل عن قصد: الساعة تقرأه لين ';' فيقدر يحتوي ':' بدون لبس.
/// daysMask: bit0 = الاثنين .. bit6 = الأحد (نفس ترقيم DateTime.weekday ١..٧).
/// أرقام النمط/الشدة تنقلب بنفس معادلة sendCodeToHostDirect (٤ ناقص القيمة)
/// عشان تطابق ترتيب أرقام الفيرموير بالضبط.
String buildWatchSchedulePayload(Iterable<Map<String, dynamic>> metas) {
  final entries = <String>[];

  for (final meta in metas) {
    if (entries.length >= _kMaxWatchReminders) {
      debugPrint(
        'buildWatchSchedulePayload: تجاوزنا $_kMaxWatchReminders تذكير — الباقي ما يُرسل للساعة',
      );
      break;
    }

    final hour24 = meta['hour24'] as int?;
    final minute = meta['minute'] as int?;
    if (hour24 == null || minute == null) continue;

    final weekdays = _weekdaysOf(
      List<String>.from(meta['daysActive'] as List? ?? const []),
    );
    final once = weekdays.isEmpty;
    // تذكير غير متكرر: نرسل يوم أقرب موعد قادم مع once=1، فالساعة تطلقه مرة
    // وحدة وتشطبه بدل ما يصير أسبوعيًا.
    final effective = once
        ? <int>{_nextInstanceOf(hour24, minute).weekday}
        : weekdays;

    var mask = 0;
    for (final weekday in effective) {
      mask |= 1 << (weekday - 1);
    }
    if (mask == 0) continue;

    final pattern = 4 - ((meta['vibrationPattern'] as int? ?? 1).clamp(1, 3));
    final power = 4 - ((meta['vibrationPower'] as int? ?? 2).clamp(1, 3));
    final label = sanitizeWatchLabel(meta['label'] as String? ?? '');
    entries.add('$hour24:$minute:$mask:$pattern:$power:${once ? 1 : 0}:$label');
  }

  return entries.join(';');
}

class ReminderAlarmService {
  static Future<void>? _ready;

  /// التهيئة تصير مرة وحدة فقط، وأي استدعاء لجدولة/إلغاء ينتظرها أولًا —
  /// شاشة التذكيرات ممكن تنادي scheduleReminder قبل ما تخلص التهيئة اللي
  /// انطلقت من main() بدون await.
  static Future<void> _ensureReady() {
    final existing = _ready;
    if (existing != null) return existing;

    final started = _initializeOnce();
    _ready = started;
    // لو فشلت التهيئة ما نخلي الفشل يعلق للأبد — نسمح بمحاولة جديدة بعدين.
    unawaited(
      started.catchError((Object e) {
        _ready = null;
        debugPrint('ReminderAlarmService: initialize failed — $e');
      }),
    );
    return started;
  }

  /// نقطة الدخول من main(). ما ترمي أبدًا: فشل التهيئة ما يصح يوقف بدء
  /// التطبيق ولا يظهر كخطأ غير معالج.
  static Future<void> initialize() async {
    try {
      await _ensureReady();
    } catch (_) {
      // مسجّل أصلًا داخل _ensureReady
    }
  }

  static Future<void> _initializeOnce() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_kAppTimeZone));

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_kReminderChannel);

    await AndroidAlarmManager.initialize();

    // "جدولة إنذار دقيق" على أندرويد ١٣+ صلاحية خاصة ما تُمنح تلقائيًا ولا
    // عن طريق نافذة الأذونات المعتادة — لازم المستخدم يوافق عليها من
    // إعدادات النظام مباشرة. طلبها هنا (مرة عند بدء التطبيق) يفتح تلك
    // الشاشة أول مرة بدل ما تُكتشف المشكلة بصمت لما تذكير ما يشتغل بوقته.
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    await _rearmSavedReminders();
  }

  /// يجدول التذكير: إشعارًا مجدولًا لكل يوم مفعّل (متكرر أسبوعيًا بشكل
  /// أصلي)، أو إشعارًا واحدًا لو ما فيه أيام محددة.
  static Future<void> scheduleReminder({
    required String reminderId,
    required String label,
    required int hour24,
    required int minute,
    required List<String> daysActive,
    required int vibrationPattern,
    required int vibrationPower,
  }) async {
    await _ensureReady();

    final base = reminderAlarmId(reminderId);

    // نلغي أي جدولة سابقة لنفس التذكير قبل ما نعيد جدولته — عشان تعديل
    // الأيام ما يخلّي إشعارات أيام قديمة معلّقة.
    await _cancelSlots(base);

    final oneShotAt = await _scheduleReminderNotifications(
      base: base,
      label: label,
      hour24: hour24,
      minute: minute,
      weekdays: _weekdaysOf(daysActive),
    );

    final meta = <String, dynamic>{
      'label': label,
      'hour24': hour24,
      'minute': minute,
      'daysActive': daysActive,
      'vibrationPattern': vibrationPattern,
      'vibrationPower': vibrationPower,
      // موعد التذكير غير المتكرر — نعرف منه لاحقًا إنه انتهى فنمسحه بدل ما
      // تعيد _rearmSavedReminders إحياءه كل مرة يُفتح التطبيق.
      if (oneShotAt != null) 'oneShotAtIso': oneShotAt.toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kReminderMetaPrefsPrefix$base', jsonEncode(meta));

    await _scheduleWatchPing(base, meta);
    await pushScheduleToWatch();
  }

  static Future<void> cancelReminder(String reminderId) async {
    await _ensureReady();
    final base = reminderAlarmId(reminderId);
    await _cancelSlots(base);
    await AndroidAlarmManager.cancel(base);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kReminderMetaPrefsPrefix$base');
    await pushScheduleToWatch();
  }

  static Future<void> _cancelSlots(int base) async {
    for (var slot = 0; slot <= 7; slot++) {
      await _notifications.cancel(id: base + slot);
    }
  }

  /// شبكة أمان: تعيد جدولة كل تذكير محفوظ عند كل تشغيل للتطبيق. جدولة نفس
  /// الأرقام مرة ثانية تستبدل السابقة، فتكرارها آمن. تغطي الحالات اللي
  /// يفقد فيها النظام المواعيد (إيقاف قسري من إعدادات البطارية مثلًا).
  static Future<void> _rearmSavedReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith(_kReminderMetaPrefsPrefix)) continue;

      final base = int.tryParse(key.substring(_kReminderMetaPrefsPrefix.length));
      // مفاتيح بترقيم قديم (قبل حجز ٨ أرقام لكل تذكير) — ما عادت صالحة.
      if (base == null || base % 8 != 0) {
        await prefs.remove(key);
        continue;
      }

      final raw = prefs.getString(key);
      if (raw == null) continue;

      try {
        final meta = jsonDecode(raw) as Map<String, dynamic>;
        final daysActive = List<String>.from(
          meta['daysActive'] as List? ?? const [],
        );

        if (daysActive.isEmpty) {
          // تذكير غير متكرر: لو وقته فات خلاص، نمسحه بدل ما نحييه لبكرة.
          final iso = meta['oneShotAtIso'] as String?;
          final at = iso == null ? null : DateTime.tryParse(iso);
          if (at == null || at.isBefore(now)) {
            await prefs.remove(key);
            continue;
          }
        }

        await _scheduleReminderNotifications(
          base: base,
          label: meta['label'] as String? ?? 'تذكير',
          hour24: meta['hour24'] as int,
          minute: meta['minute'] as int,
          weekdays: _weekdaysOf(daysActive),
        );
        await _scheduleWatchPing(base, meta);
      } catch (e) {
        debugPrint('_rearmSavedReminders($key): $e');
      }
    }

    // وبنفس المناسبة: نعيد إرسال الجدول للساعة عند كل تشغيل، فتلحق ساعة كانت
    // مطفية أو خارج الشبكة وقت آخر تعديل.
    await pushScheduleToWatch();
  }

  /// يرسل جدول التذكيرات كامل للساعة عشان تطلقها من ساعتها الداخلية.
  ///
  /// يُنادى تلقائيًا بعد أي تغيير على التذكيرات وعند بدء التطبيق. مناسب كمان
  /// للاستدعاء من شاشة الساعة بعد نجاح الاتصال بها (أو بعد تغيير عنوانها)،
  /// عشان ساعة جديدة/مُعاد ضبطها تاخذ الجدول فورًا بدل ما تنتظر أول تعديل.
  ///
  /// "أفضل جهد": لو الساعة مطفية أو خارج الشبكة نتجاهل بهدوء — الجدول محفوظ
  /// بالجوال ويُعاد إرساله بالمرة الجاية.
  static Future<void> pushScheduleToWatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final watchIp = prefs.getString(kWatchIpPrefsKey);
      if (watchIp == null || watchIp.isEmpty) return;

      final metas = <Map<String, dynamic>>[];
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_kReminderMetaPrefsPrefix)) continue;
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          metas.add(jsonDecode(raw) as Map<String, dynamic>);
        } catch (e) {
          debugPrint('pushScheduleToWatch: تعذّر فك $key — $e');
        }
      }

      await WatchAudioSocket.sendRemindersToHost(
        watchIp,
        buildWatchSchedulePayload(metas),
        timeout: const Duration(seconds: 3),
      ).timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('pushScheduleToWatch: $e');
    }
  }

  /// للتشخيص: كل الإشعارات المجدولة فعليًا عند النظام الآن. مفيدة للتأكد إن
  /// التذكيرات مسجّلة وما راحت مع إيقاف قسري للتطبيق.
  static Future<List<PendingNotificationRequest>> pendingReminders() async {
    await _ensureReady();
    return _notifications.pendingNotificationRequests();
  }
}

// يحتاج @pragma('vm:entry-point') لأن AlarmManager يستدعيه من عزلة (isolate)
// خلفية جديدة تمامًا — بدون هذا الـ pragma ممكن الـ tree shaking وقت البناء
// يشيله لأنه ما يشوف أي استدعاء مباشر له من main()/التطبيق نفسه.
//
// مهمته الوحيدة الآن: اهتزاز الساعة. الإشعار مجدول أصلًا عند النظام، فلو ما
// وصلت هذي الدالة لأي سبب (النظام قتل العزلة، تزاحم مع عزلة خلفية ثانية،
// إيقاف قسري) التذكير يظهر بالجوال عادي.
@pragma('vm:entry-point')
Future<void> reminderAlarmCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final rawMeta = prefs.getString('$_kReminderMetaPrefsPrefix$id');
  if (rawMeta == null) return; // تم إلغاء هذا التذكير بعد ما جُدول

  final meta = jsonDecode(rawMeta) as Map<String, dynamic>;
  final daysActive = List<String>.from(meta['daysActive'] as List? ?? const []);
  final vibrationPattern = meta['vibrationPattern'] as int? ?? 1;
  final vibrationPower = meta['vibrationPower'] as int? ?? 2;

  // إعادة جدولة تنبيه الساعة أولًا: الحزمة تنادي هذي الدالة بدون await،
  // فالخدمة الأصلية تعتبر المهمة خلصت عند أول await وممكن تهدم العزلة — أي
  // شي بالنهاية يسابق الهدم.
  if (daysActive.isNotEmpty) {
    await _scheduleWatchPing(id, meta);
  }

  final watchIp = prefs.getString(kWatchIpPrefsKey);
  if (watchIp == null || watchIp.isEmpty) return;

  // الفيرموير يفهم فقط أرقام أنماط اهتزاز '1'-'3' — التطبيق يعرض خيار رابع
  // للمنبّهات ("تصاعدي") ما له مقابل بالساعة، فنحصره بأقصى ٣ قبل التحويل.
  // نفس معادلة التحويل المستخدمة لأكواد اكتشاف الصوت الحالية.
  final clampedPattern = vibrationPattern.clamp(1, 3);
  final clampedPower = vibrationPower.clamp(1, 3);
  try {
    await WatchAudioSocket.sendCodeToHostDirect(
      watchIp,
      'T', // تذكير — انظر main.cpp: result_codes[]
      pattern: 4 - clampedPattern,
      power: 4 - clampedPower,
      timeout: const Duration(seconds: 3),
    ).timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('reminderAlarmCallback: watch notify failed — $e');
  }
}
