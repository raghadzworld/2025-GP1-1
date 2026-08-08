import 'package:flutter/foundation.dart';

/// App-wide toggle for sign-language explainer mode.
/// Shared across screens so activating it on one page keeps it active
/// (and the header button green) when navigating to another.
final ValueNotifier<bool> signLanguageModeNotifier = ValueNotifier<bool>(false);
