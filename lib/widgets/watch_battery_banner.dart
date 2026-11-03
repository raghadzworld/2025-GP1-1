import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../screens/nabeeh_colors.dart';
import '../services/watch_battery_alert.dart';
import '../services/watch_link.dart';

/// بانر أعلى الشاشة داخل التطبيق لما شحن الساعة ينخفض — يبان فوق أي شاشة
/// (مركّب بـ MaterialApp.builder) بدون ما يوقف المستخدم عن اللي يسويه.
/// ٢٠٪: بانر هادي. ١٠٪: أحمر وأوضح. "إغلاق" يخفيه لين المرحلة الجاية.
class WatchBatteryBanner extends StatefulWidget {
  const WatchBatteryBanner({super.key});

  @override
  State<WatchBatteryBanner> createState() => _WatchBatteryBannerState();
}

class _WatchBatteryBannerState extends State<WatchBatteryBanner> {
  BatteryLevel _dismissed = BatteryLevel.none;

  @override
  void initState() {
    super.initState();
    WatchLink.instance.status.addListener(_onStatus);
  }

  @override
  void dispose() {
    WatchLink.instance.status.removeListener(_onStatus);
    super.dispose();
  }

  void _onStatus() {
    final pct = WatchLink.instance.status.value?.batteryPercent ?? -1;
    // انشحنت — الإغلاق السابق ما يعود يحسب للمرة الجاية
    if (pct >= kWatchBatteryRearmPercent && _dismissed != BatteryLevel.none) {
      _dismissed = BatteryLevel.none;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pct = WatchLink.instance.status.value?.batteryPercent ?? -1;
    final level = batteryLevelFor(pct);
    final visible =
        level != BatteryLevel.none && level.index > _dismissed.index;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -1.5),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _BannerCard(
                  percent: pct,
                  critical: level == BatteryLevel.critical,
                  onDismiss: () => setState(() => _dismissed = level),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final int percent;
  final bool critical;
  final VoidCallback onDismiss;

  const _BannerCard({
    required this.percent,
    required this.critical,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE53935);
    final accent = critical ? red : NabeehColors.lightBlue;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: critical ? const Color(0xFFFFF1F0) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: critical ? 0.6 : 0.35),
              width: critical ? 1.6 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  critical ? LucideIcons.batteryWarning : LucideIcons.batteryLow,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'الساعة تحتاج شحن',
                      style: TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: critical ? red : NabeehColors.dark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'المتبقي $percent٪ فقط',
                      style: const TextStyle(
                        fontFamily: 'IBMPlexSansArabic',
                        fontSize: 13,
                        color: NabeehColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // بوكس بإطار وخلفية خفيفة عشان يبان إنه زر، مو مجرد كلمة
              OutlinedButton(
                onPressed: onDismiss,
                style: OutlinedButton.styleFrom(
                  foregroundColor: critical ? red : NabeehColors.darkBlue,
                  backgroundColor: accent.withValues(alpha: 0.08),
                  side: BorderSide(color: accent.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'إغلاق',
                  style: TextStyle(
                    fontFamily: 'IBMPlexSansArabic',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
