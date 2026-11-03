import 'package:flutter_test/flutter_test.dart';
import 'package:nabbeh/services/watch_battery_alert.dart';

BatteryAlertAction decide(int pct, {bool alerted = false}) =>
    decideBatteryAlert(batteryPercent: pct, alreadyAlerted: alerted);

void main() {
  test('ينبّه أول ما يوصل ٢٠٪', () {
    expect(decide(21), BatteryAlertAction.none);
    expect(decide(20), BatteryAlertAction.alert);
    expect(decide(5), BatteryAlertAction.alert);
  });

  test('ما يكرر التنبيه وهو تحت ٢٥٪', () {
    expect(decide(19, alerted: true), BatteryAlertAction.none);
    expect(decide(21, alerted: true), BatteryAlertAction.none);
    expect(decide(24, alerted: true), BatteryAlertAction.none);
  });

  test('يرجع يجهّز التنبيه بعد الشحن لـ ٢٥٪', () {
    expect(decide(25, alerted: true), BatteryAlertAction.rearm);
    expect(decide(80, alerted: true), BatteryAlertAction.rearm);
  });

  test('يتجاهل القراءة لو البطارية غير متوفرة (-1)', () {
    expect(decide(-1), BatteryAlertAction.none);
    expect(decide(-1, alerted: true), BatteryAlertAction.none);
  });
}
