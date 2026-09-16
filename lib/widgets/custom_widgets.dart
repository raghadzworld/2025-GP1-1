import 'package:flutter/material.dart';
import '../screens/Nabeeh_Colors.dart';

/// خلفية الفقاعات المتحركة المستخدمة في شاشات الترحيب/الانترو —
/// كحلية غامقة مع دوائر متوهجة تتموّج ببطء. مشتركة بين أكثر من شاشة
/// حتى ما تتكرر نفس الدوائر والأنيميشنات.
class NabeehBubbleBackground extends StatefulWidget {
  const NabeehBubbleBackground({super.key});

  @override
  State<NabeehBubbleBackground> createState() =>
      _NabeehBubbleBackgroundState();
}

class _NabeehBubbleBackgroundState extends State<NabeehBubbleBackground>
    with TickerProviderStateMixin {
  late AnimationController _wave1Controller;
  late AnimationController _wave2Controller;
  late AnimationController _wave3Controller;
  late AnimationController _wave4Controller;

  late Animation<Offset> _wave1Anim;
  late Animation<Offset> _wave2Anim;
  late Animation<Offset> _wave3Anim;
  late Animation<Offset> _wave4Anim;

  @override
  void initState() {
    super.initState();

    _wave1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _wave2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _wave3Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    _wave4Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _wave1Anim =
        Tween<Offset>(begin: Offset.zero, end: const Offset(80, -120)).animate(
          CurvedAnimation(parent: _wave1Controller, curve: Curves.easeInOut),
        );
    _wave2Anim =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-90, 100)).animate(
          CurvedAnimation(parent: _wave2Controller, curve: Curves.easeInOut),
        );
    _wave3Anim =
        Tween<Offset>(begin: Offset.zero, end: const Offset(70, -80)).animate(
          CurvedAnimation(parent: _wave3Controller, curve: Curves.easeInOut),
        );
    _wave4Anim =
        Tween<Offset>(begin: Offset.zero, end: const Offset(-60, 70)).animate(
          CurvedAnimation(parent: _wave4Controller, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _wave1Controller.dispose();
    _wave2Controller.dispose();
    _wave3Controller.dispose();
    _wave4Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: const Color(0xFF1a1760)),
        _buildAnimatedCircle(
          _wave1Anim,
          -80,
          -30,
          380,
          const Color(0xFF6AB8F0),
          0.6,
        ),
        _buildAnimatedCircle(
          _wave2Anim,
          160,
          -220,
          420,
          const Color(0xFF5080D8),
          0.65,
        ),
        _buildAnimatedCircle(
          _wave3Anim,
          320,
          -10,
          340,
          const Color(0xFF6AB8F0),
          0.6,
        ),
        _buildAnimatedCircle(
          _wave4Anim,
          -100,
          190,
          280,
          const Color(0xFFAADDF5),
          0.55,
        ),
        _buildAnimatedCircle(
          _wave1Anim,
          130,
          230,
          260,
          const Color(0xFFD0EEFA),
          0.5,
        ),
        _buildAnimatedCircle(
          _wave2Anim,
          20,
          290,
          220,
          const Color(0xFF7BBDE0),
          0.5,
        ),
        _buildAnimatedCircle(
          _wave3Anim,
          550,
          -60,
          280,
          const Color(0xFFAADDF5),
          0.55,
        ),
        _buildAnimatedCircle(
          _wave4Anim,
          480,
          250,
          300,
          const Color(0xFF6AB8F0),
          0.6,
        ),
        _buildAnimatedCircle(
          _wave1Anim,
          600,
          180,
          240,
          const Color(0xFFD0EEFA),
          0.5,
        ),
        _buildAnimatedCircle(
          _wave2Anim,
          520,
          -20,
          200,
          const Color(0xFF7BBDE0),
          0.5,
        ),
        _buildAnimatedCircle(
          _wave3Anim,
          650,
          280,
          220,
          const Color(0xFFAADDF5),
          0.45,
        ),
        _buildAnimatedCircle(
          _wave4Anim,
          700,
          50,
          260,
          const Color(0xFF6AB8F0),
          0.5,
        ),
      ],
    );
  }

  Widget _buildAnimatedCircle(
    Animation<Offset> animation,
    double top,
    double left,
    double size,
    Color color,
    double opacity,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Positioned(
          top: top + animation.value.dy,
          left: left + animation.value.dx,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: opacity),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

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
