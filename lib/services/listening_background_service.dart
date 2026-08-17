import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../features/categories/data/models/sound_setting_model.dart';
import '../features/categories/data/services/category_service.dart';
import 'audio_utils.dart';
import 'event_classifier_service.dart';
import 'watch_audio_socket.dart';

const kListeningNotificationChannelId = 'nabeeh_listening_channel';
const kListeningNotificationId = 8901;

const Map<String, String> _kCategoryLabels = {
  'doorbell': 'جرس الباب',
  'knock': 'طرق على الباب',
  'baby_cry': 'بكاء طفل',
  'fire_alarm': 'إنذار حريق',
  'adhan': 'أذان',
};

const Map<String, String> _kAlertEmojis = {
  'fire_alarm': '🚨',
  'adhan': '🕌',
  'baby_cry': '👶🏻',
  'doorbell': '🔔',
  'knock': '✊🏻',
};

const Map<String, String> _kWatchDetectionCodes = {
  'doorbell': 'D',
  'knock': 'K',
  'baby_cry': 'B',
  'fire_alarm': 'F',
  'adhan': 'A',
};

const Map<String, String> _kApiLabelToSoundId = {
  'doorbell': 'door_bell',
  'knock': 'door_knock',
  'baby_cry': 'baby_cry',
  'fire_alarm': 'fire_alarm',
  'adhan': 'adhan',
};

int _toWatchVibrationCode(int appValue) => 4 - appValue;

const int _kChunkSeconds = 3;
const int _kBytesPerChunk = WatchAudioSocket.sampleRate * 2 * _kChunkSeconds;
const int _kMaxDetectionEntries = 30;

/// يُستدعى مرة وحدة من main() قبل runApp — يجهّز قناة الإشعار الإلزامية
/// ويهيّئ خدمة الخلفية بدون تشغيلها (تشتغل فقط لما المستخدم يضغط المايك).
Future<void> initializeBackgroundService() async {
  final notifications = FlutterLocalNotificationsPlugin();
  const channel = AndroidNotificationChannel(
    kListeningNotificationChannelId,
    'استماع نبيه',
    description: 'يظهر طول ما التطبيق يستمع لصوت الساعة في الخلفية',
    importance: Importance.low,
  );
  await notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  final service = FlutterBackgroundService();
  await service.configure(
    iosConfiguration: IosConfiguration(autoStart: false),
    androidConfiguration: AndroidConfiguration(
      onStart: onListeningServiceStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: kListeningNotificationChannelId,
      foregroundServiceNotificationId: kListeningNotificationId,
      initialNotificationTitle: 'نبيه',
      initialNotificationContent: 'جاري التحضير...',
      foregroundServiceTypes: [
        AndroidForegroundType.connectedDevice,
        AndroidForegroundType.dataSync,
      ],
    ),
  );
}

/// نقطة دخول الخدمة الخلفية — تشتغل بـ isolate منفصل تمامًا عن واجهة التطبيق،
/// فلازم تهيّئ Firebase من جديد وتدير كل شيء بنفسها (اتصال الساعة، التصنيف،
/// إعدادات المجموعة الصوتية، وإرسال النتيجة والاهتزاز للساعة).
@pragma('vm:entry-point')
void onListeningServiceStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  // نأجّل انتظار تهيئة Firebase لآخر لحظة ممكنة (داخل الـ handler وقت
  // الحاجة الفعلية له) بدل ما نوقف تسجيل مستمعي service.on(...) خلفه —
  // لو المستخدم ضغط المايك بسرعة ووصل أول invoke قبل ما نسجّل المستمع،
  // البلجن يتجاهله بصمت بدون أي إعادة محاولة (لا استثناء ولا خطأ)، فتضل
  // الواجهة عالقة على "جاري الاتصال" للأبد. تسجيل المستمعين فورًا يقلّل
  // نافذة السباق هذي لأقل قدر ممكن.
  final firebaseReady =
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final watchSocket = WatchAudioSocket();
  // ما نبنيه إلا بعد ما نتأكد إن Firebase انتهت تهيئته — بناؤه فورًا هنا
  // كان يفجّر استثناء غير ملتقط (Firebase.app() قبل ما initializeApp يخلص)
  // يوقف onListeningServiceStart بالكامل قبل ما يوصل لتسجيل service.on(...)،
  // يعني كل ضغطة مايك تعلّق للأبد بدون ما يوصل أي رد للواجهة أبدًا.
  CategoryService? categoryService;
  final pcmBuffer = <int>[];
  final detections = <Map<String, String>>[];
  Map<String, SoundSettingModel> activeSoundSettings = {
    for (final sound in CategoryService.defaultSounds) sound.soundId: sound,
  };

  bool isListening = false;
  bool isConnecting = false;
  bool isClassifying = false;
  double audioLevel = 0.0;
  String statusText = 'الميكروفون متوقف';

  void emitUpdate() {
    service.invoke('update', {
      'isListening': isListening,
      'isConnecting': isConnecting,
      'statusText': statusText,
      'audioLevel': audioLevel,
      'detections': detections,
    });
  }

  Future<void> setNotification(String content) async {
    if (service is AndroidServiceInstance) {
      await service.setForegroundNotificationInfo(
        title: 'نبيه يستمع',
        content: content,
      );
    }
  }

  Future<void> loadActiveSoundSettings() async {
    try {
      categoryService ??= CategoryService.withDefaults();
      final categories = await categoryService!.getCategories();
      final activeMatches = categories.where((c) => c.isEnabled);
      if (activeMatches.isEmpty) return;
      final active = activeMatches.first;
      activeSoundSettings = {
        for (final sound in active.sounds) sound.soundId: sound,
      };
    } catch (_) {
      // نكمل بالإعدادات الافتراضية لو تعذر التحميل
    }
  }

  Future<void> classifyChunk(Uint8List pcmChunk) async {
    isClassifying = true;
    final wavBytes = pcm16ToWav(pcmChunk, sampleRate: WatchAudioSocket.sampleRate);
    try {
      final result = await EventClassifierService.classifyWavChunk(wavBytes);
      if (!isListening) return;

      final emoji = _kAlertEmojis[result.label];
      final soundId = _kApiLabelToSoundId[result.label];
      final soundSetting = soundId != null ? activeSoundSettings[soundId] : null;
      final isSoundEnabled = soundSetting?.isEnabled ?? false;

      if (result.shouldAlert && emoji != null && isSoundEnabled) {
        final hour = DateTime.now().hour;
        final isAm = hour < 12;
        final hour12 = hour % 12 == 0 ? 12 : hour % 12;
        final minute = DateTime.now().minute.toString().padLeft(2, '0');
        final label = _kCategoryLabels[result.label] ?? result.label;

        detections.insert(0, {
          'emoji': emoji,
          'label': label,
          'time': '$hour12:$minute ${isAm ? 'ص' : 'م'}',
        });
        if (detections.length > _kMaxDetectionEntries) {
          detections.removeLast();
        }

        statusText = label;
        await setNotification('آخر اكتشاف: $label');
        emitUpdate();

        final watchCode = _kWatchDetectionCodes[result.label];
        if (watchCode != null) {
          await watchSocket.sendDetectionCode(
            watchCode,
            pattern: _toWatchVibrationCode(soundSetting!.vibrationPattern),
            power: _toWatchVibrationCode(soundSetting.vibrationPower),
          );
        }
      }
    } catch (_) {
      // نتجاهل فشل تصنيف مقطع واحد ونكمل بالمقطع اللي بعده
    } finally {
      isClassifying = false;
    }
  }

  DateTime lastLevelEmit = DateTime.fromMillisecondsSinceEpoch(0);
  void onAudioData(Uint8List data) {
    audioLevel = pcm16PeakAmplitude(data);
    // نحدّث التطبيق بمستوى الصوت كل ١٥٠ملي ثانية بس (مو كل حزمة توصل) —
    // كافي لرسم موجة حية بدون إغراق قناة الاتصال بين الـ isolate والواجهة.
    final now = DateTime.now();
    if (now.difference(lastLevelEmit) > const Duration(milliseconds: 150)) {
      lastLevelEmit = now;
      emitUpdate();
    }

    pcmBuffer.addAll(data);
    if (pcmBuffer.length >= _kBytesPerChunk) {
      final chunk = Uint8List.fromList(pcmBuffer.sublist(0, _kBytesPerChunk));
      pcmBuffer.removeRange(0, _kBytesPerChunk);
      if (!isClassifying) {
        classifyChunk(chunk);
      }
    }
  }

  Future<void> stopListening() async {
    await watchSocket.stop();
    pcmBuffer.clear();
    isListening = false;
    isConnecting = false;
    audioLevel = 0.0;
    statusText = 'الميكروفون متوقف';
    emitUpdate();
    await service.stopSelf();
  }

  void onSocketDone() {
    if (isListening) stopListening();
  }

  service.on('start_listening').listen((event) async {
    // الواجهة تعيد إرسال هذا الطلب كم مرة لين تتأكد إنه وصل (تحسّبًا لسباق
    // بدء الخدمة) — لو أصلاً نتّصل أو متّصلين، بس نأكّد الحالة الحالية
    // ونتجاهل الطلب المكرر بدل ما نبدأ اتصال ثاني فوق الأول.
    if (isConnecting || isListening) {
      emitUpdate();
      return;
    }

    final ip = event?['watchIp'] as String? ??
        (await SharedPreferences.getInstance()).getString('watch_ip');
    if (ip == null || ip.isEmpty) {
      statusText = 'تعذّر الاتصال — لا يوجد عنوان IP محفوظ للساعة';
      emitUpdate();
      return;
    }

    isConnecting = true;
    statusText = 'جاري الاتصال بالساعة...';
    emitUpdate();

    // نغلّف كل خطوات الاتصال بسقف زمني واحد — لو أي خطوة تعلّقت لأي سبب
    // (تهيئة Firebase، جلب الإعدادات، أو اتصال الساعة نفسه)، ما نخلي
    // الواجهة تعلّق للأبد بانتظار رد ما راح يوصل؛ نطلع خطأ واضح بدلها.
    try {
      await Future(() async {
        await firebaseReady;
        await setNotification('جاري الاتصال بالساعة...');
        pcmBuffer.clear();
        detections.clear();
        await loadActiveSoundSettings();
        await watchSocket.connect(
          host: ip,
          onData: onAudioData,
          onError: (_) => stopListening(),
          onDone: onSocketDone,
        );
      }).timeout(const Duration(seconds: 15));
      isConnecting = false;
      isListening = true;
      statusText = 'جاري الاستماع من الساعة...';
      emitUpdate();
      await setNotification('يستمع لصوت الساعة الآن');
    } catch (e) {
      isConnecting = false;
      isListening = false;
      statusText = 'تعذّر الاتصال بالساعة — تأكد من عنوان IP والشبكة';
      emitUpdate();
      await service.stopSelf();
    }
  });

  service.on('stop_listening').listen((_) => stopListening());

  service.on('request_status').listen((_) => emitUpdate());
}
