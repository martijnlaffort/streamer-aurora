import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Type system per PRD §10: one strong display face for titles (Outfit) and
/// a clean UI face for everything else (Inter). Sizes/weights are the tokens;
/// change them here, nowhere else.
///
/// Both faces are bundled as assets (see `pubspec.yaml`) rather than fetched at
/// runtime, so the app makes no network call to render its own chrome and looks
/// correct on a cold first launch with no connection.
abstract final class AppTypography {
  /// Declared in `pubspec.yaml`. Named here so no call site spells them as bare
  /// strings — a typo'd family silently falls back to the platform default,
  /// which is the kind of bug you only notice in a screenshot.
  static const String displayFamily = 'Outfit';
  static const String uiFamily = 'Inter';

  static TextStyle get display => TextStyle(
        fontFamily: displayFamily,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.1,
        color: AppColors.textPrimary,
      );

  static TextStyle get title => TextStyle(
        fontFamily: displayFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => TextStyle(
        fontFamily: uiFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.textPrimary,
      );

  static TextStyle get label => TextStyle(
        fontFamily: uiFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        color: AppColors.textSecondary,
      );
}
