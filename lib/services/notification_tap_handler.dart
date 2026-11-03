import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// payload إشعار شحن الساعة — الضغط عليه يفتح تبويب الساعة (فيه البطارية)
const kWatchBatteryPayload = 'watch_battery';

/// ترتيب تبويب "الساعة" بالشريط السفلي في MainScreen
const kWatchTabIndex = 1;

/// مفتاح الـ Navigator الرئيسي — عشان نرجع للشاشة الرئيسية من برا الواجهة
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// طلب تبديل تبويب بـ MainScreen. يبقى محفوظ لين MainScreen يطبّقه — حتى
/// لو التطبيق كان مقفول وانفتح من الإشعار قبل ما تنبني الشاشة.
final ValueNotifier<int?> mainTabRequest = ValueNotifier<int?>(null);

/// كل الإشعارات (المنبهات وشحن الساعة) تستخدم نفس البلجن، وآخر initialize
/// يحدد معالج الضغط — فكلهم يمررون هذي الدالة نفسها.
void onNabeehNotificationTap(NotificationResponse response) {
  if (response.payload != kWatchBatteryPayload) return;
  // نرجع للشاشة الرئيسية لو المستخدم داخل شاشة ثانية فوقها
  appNavigatorKey.currentState?.popUntil(
    (route) => route.settings.name == '/main' || route.isFirst,
  );
  mainTabRequest.value = kWatchTabIndex;
}

/// لو التطبيق كان مقفول تمامًا وانفتح بالضغط على إشعار — يُستدعى مرة عند
/// بدء التطبيق.
Future<void> handleNotificationLaunch() async {
  try {
    final details =
        await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if ((details?.didNotificationLaunchApp ?? false) && response != null) {
      onNabeehNotificationTap(response);
    }
  } catch (_) {}
}
