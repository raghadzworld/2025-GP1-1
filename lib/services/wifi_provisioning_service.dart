import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

final Guid _kServiceUuid = Guid('b19c1e70-1fc7-4b2b-9f5b-8f2e6f2b1a01');
final Guid _kCharacteristicUuid = Guid('b19c1e71-1fc7-4b2b-9f5b-8f2e6f2b1a01');
final Guid _kResultCharacteristicUuid = Guid('b19c1e72-1fc7-4b2b-9f5b-8f2e6f2b1a01');
const String _kDeviceName = 'Nabeeh-Watch-Setup';

enum WifiProvisioningStep { scanning, connecting, writing, confirming, done }

class WifiProvisioningException implements Exception {
  final String message;
  WifiProvisioningException(this.message);

  @override
  String toString() => message;
}

/// يزوّد الساعة ببيانات الواي فاي عبر BLE — قناة منفصلة تمامًا عن قناة
/// TCP (الصوت/النتائج)، تُستخدم فقط لإرسال SSID وكلمة السر مرة واحدة.
class WifiProvisioningService {
  static Future<void> provision({
    required String ssid,
    required String password,
    required void Function(WifiProvisioningStep step) onStep,
    int scanAttempts = 3,
    Duration scanTimeout = const Duration(seconds: 6),
  }) async {
    if (!await FlutterBluePlus.isSupported) {
      throw WifiProvisioningException('البلوتوث غير مدعوم على هذا الجهاز');
    }
    // adapterStateNow قيمة مخزّنة (cached) تضل unknown لين أول مرة نستمع
    // فعليًا لـ stream الحالة — استخدامها مباشرة يعطي نتيجة خاطئة (البلوتوث
    // شغّال فعلاً بس الكود يفتكره unknown) أول ما نفتح الشاشة بجلسة جديدة.
    var state = FlutterBluePlus.adapterStateNow;
    if (state != BluetoothAdapterState.on) {
      state = await FlutterBluePlus.adapterState
          .firstWhere((s) => s != BluetoothAdapterState.unknown)
          .timeout(const Duration(seconds: 3), onTimeout: () => state);
    }
    if (state != BluetoothAdapterState.on) {
      throw WifiProvisioningException('يرجى تفعيل البلوتوث أولاً');
    }

    // ما فيه طريقة نتأكد فيها إن بلوتوث الساعة شغّال إلا بالبحث نفسه — لو
    // لقينا الجهاز يعني شغّال، ولو ما لقيناه ممكن المستخدم ما ضغط الزر بعد
    // أو ضغطه بس البث لسا ما بدأ، فنعطيه فرصة ونعيد المحاولة بعد فاصل بسيط.
    onStep(WifiProvisioningStep.scanning);
    BluetoothDevice? device;
    for (var attempt = 0; attempt < scanAttempts && device == null; attempt++) {
      if (attempt > 0) await Future.delayed(const Duration(seconds: 2));
      device = await _scanOnce(scanTimeout);
    }
    if (device == null) {
      throw WifiProvisioningException(
        'تعذّر العثور على الساعة — تأكدي إنك ضغطتِ زر "تغيير شبكة الواي فاي" '
        'من إعدادات الساعة، وإن البلوتوث مفعّل على الساعة، ثم حاولي مرة أخرى',
      );
    }

    onStep(WifiProvisioningStep.connecting);
    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 10),
      );

      final services = await device.discoverServices();
      final service = services.where((s) => s.uuid == _kServiceUuid).firstOrNull;
      if (service == null) {
        throw WifiProvisioningException('لم يتم العثور على خدمة التزويد على الساعة');
      }

      final characteristic = service.characteristics
          .where((c) => c.uuid == _kCharacteristicUuid)
          .firstOrNull;
      if (characteristic == null) {
        throw WifiProvisioningException('لم يتم العثور على قناة الكتابة على الساعة');
      }

      // نشترك بقناة النتيجة (لو موجودة) قبل الكتابة عشان ما تفوتنا الاستجابة
      final resultCharacteristic = service.characteristics
          .where((c) => c.uuid == _kResultCharacteristicUuid)
          .firstOrNull;
      StreamSubscription<List<int>>? resultSub;
      Completer<String>? resultCompleter;
      if (resultCharacteristic != null) {
        resultCompleter = Completer<String>();
        await resultCharacteristic.setNotifyValue(true);
        resultSub = resultCharacteristic.lastValueStream.listen((value) {
          if (value.isEmpty || resultCompleter!.isCompleted) return;
          resultCompleter.complete(utf8.decode(value, allowMalformed: true));
        });
      }

      onStep(WifiProvisioningStep.writing);
      final payload = utf8.encode('$ssid\n$password');
      final props = characteristic.properties;
      await characteristic.write(
        payload,
        withoutResponse: props.writeWithoutResponse && !props.write,
      );

      // قناة النتيجة تأكيد إضافي إن الساعة استلمت ونجحت — مو بديل عن نجاح
      // الكتابة نفسها، فلو ما جاوبت (فيرموير قديم أو تأخير) نعتبرها نجحت.
      if (resultCompleter != null) {
        onStep(WifiProvisioningStep.confirming);
        final result = await resultCompleter.future
            .timeout(const Duration(seconds: 15), onTimeout: () => '');
        await resultSub?.cancel();
        if (result.trim().toUpperCase().startsWith('F')) {
          throw WifiProvisioningException(
            'الساعة رفضت بيانات الشبكة — تأكدي من اسم الشبكة وكلمة السر وحاولي مرة أخرى',
          );
        }
      }

      onStep(WifiProvisioningStep.done);
    } finally {
      unawaited(device.disconnect());
    }
  }

  static Future<BluetoothDevice?> _scanOnce(Duration timeout) async {
    final completer = Completer<BluetoothDevice?>();
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName == _kDeviceName ||
            r.advertisementData.advName == _kDeviceName) {
          if (!completer.isCompleted) completer.complete(r.device);
          return;
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: timeout);
    final result = await completer.future
        .timeout(timeout, onTimeout: () => null);
    await FlutterBluePlus.stopScan();
    await sub.cancel();
    return result;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
