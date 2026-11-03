import 'package:flutter_test/flutter_test.dart';
import 'package:nabbeh/services/watch_battery_alert.dart';

BatteryAlertDecision decide(
  int pct, [
  BatteryLevel alerted = BatteryLevel.none,
]) =>
    decideBatteryAlert(batteryPercent: pct, alreadyAlerted: alerted);

void main() {
  test('ينبّه أول ما يوصل ٢٠٪', () {
    expect(decide(21).alert, isNull);
    expect(decide(20).alert, BatteryLevel.low);
    expect(decide(20).alerted, BatteryLevel.low);
  });

  test('ينبّه مرة ثانية أوضح عند ١٠٪', () {
    expect(decide(15, BatteryLevel.low).alert, isNull);
    expect(decide(10, BatteryLevel.low).alert, BatteryLevel.critical);
    expect(decide(10, BatteryLevel.low).alerted, BatteryLevel.critical);
  });

  test('لو أول قراءة تحت ١٠٪ ينبّه بالمرحلة الحرجة مباشرة', () {
    expect(decide(7).alert, BatteryLevel.critical);
  });

  test('ما يكرر نفس المرحلة', () {
    expect(decide(19, BatteryLevel.low).alert, isNull);
    expect(decide(5, BatteryLevel.critical).alert, isNull);
    // رجع فوق ١٠ بدون ما يوصل ٢٥ — ما نرجّع مرحلة ٢٠٪
    expect(decide(18, BatteryLevel.critical).alert, isNull);
    expect(decide(18, BatteryLevel.critical).alerted, BatteryLevel.critical);
  });

  test('يرجع يجهّز التنبيهات بعد الشحن لـ ٢٥٪', () {
    expect(decide(24, BatteryLevel.critical).alerted, BatteryLevel.critical);
    expect(decide(25, BatteryLevel.critical).alerted, BatteryLevel.none);
    expect(decide(80, BatteryLevel.low).alerted, BatteryLevel.none);
  });

  test('يتجاهل القراءة لو البطارية غير متوفرة (-1)', () {
    expect(decide(-1).alert, isNull);
    expect(decide(-1, BatteryLevel.low).alerted, BatteryLevel.low);
  });

  test('مرحلة البانر حسب النسبة', () {
    expect(batteryLevelFor(21), BatteryLevel.none);
    expect(batteryLevelFor(20), BatteryLevel.low);
    expect(batteryLevelFor(11), BatteryLevel.low);
    expect(batteryLevelFor(10), BatteryLevel.critical);
    expect(batteryLevelFor(-1), BatteryLevel.none);
  });
}
