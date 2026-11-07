import 'package:flutter/material.dart';

import '../screens/nabeeh_colors.dart';
import '../services/sign_language_mode.dart';
import 'sign_video_card.dart';

/// بوكس فيديو لغة الإشارة تحت عنوان الصفحة — بنفس شكل صفحة التواصل.
/// يظهر فقط لما وضع لغة الإشارة مفعّل، وزر الإغلاق فيه يطفّي الوضع.
class SignLanguageVideoBox extends StatelessWidget {
  final String videoAsset;
  final EdgeInsetsGeometry padding;

  const SignLanguageVideoBox({
    super.key,
    required this.videoAsset,
    this.padding = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: signLanguageModeNotifier,
      builder: (context, isActive, _) => AnimatedSize(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: isActive
            ? Padding(
                padding: padding,
                child: SignVideoCard(
                  key: ValueKey(videoAsset),
                  videoAsset: videoAsset,
                  onClose: () => signLanguageModeNotifier.value = false,
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }
}

/// زر لغة الإشارة بالهيدر: يبدّل الوضع ويتحول للأخضر عند التفعيل
/// (نفس زر صفحة التواصل).
class SignLanguageToggleButton extends StatelessWidget {
  const SignLanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: signLanguageModeNotifier,
      builder: (context, isActive, _) => GestureDetector(
        onTap: () => signLanguageModeNotifier.value = !isActive,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isActive
                ? const LinearGradient(
                    colors: [
                      Color(0xFF0B4D2C),
                      Color(0xFF0B4D2C),
                      NabeehColors.green,
                    ],
                    stops: [0.09, 0.30, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : const LinearGradient(
                    colors: [
                      NabeehColors.darkNavy,
                      NabeehColors.darkNavy,
                      NabeehColors.lightBlue,
                    ],
                    stops: [0.09, 0.30, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Image.asset(
              'assets/images/icon_signLan.png',
              color: NabeehColors.background,
              colorBlendMode: BlendMode.srcIn,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
