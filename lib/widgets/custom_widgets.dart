import 'package:flutter/material.dart';
import '../screens/Nabeeh_Colors.dart';

class BentoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final BoxBorder? border;
  final double? borderRadius;

  const BentoCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.border,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: padding ?? const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(borderRadius ?? 32),
          border: border ?? Border.all(color: NabeehColors.slate100.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: NabeehColors.dark.withValues(alpha: 0.05),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class PremiumButton extends StatelessWidget {
  final String text;
  final VoidCallback onClick;
  final Color? color;
  final Color? textColor;
  final bool isFullWidth;
  final double? padding;

  const PremiumButton({
    super.key,
    required this.text,
    required this.onClick,
    this.color,
    this.textColor,
    this.isFullWidth = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: onClick,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? NabeehColors.accent,
          foregroundColor: textColor ?? NabeehColors.dark,
          padding: EdgeInsets.symmetric(vertical: padding ?? 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          shadowColor: (color ?? NabeehColors.accent).withValues(alpha: 0.2),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
