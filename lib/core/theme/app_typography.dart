import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Type tokens per PRD §10: one strong display face for titles + a clean UI
/// face for metadata. Font *assets* land with the visual pass (Task 1.8); until
/// then these ride the platform default family so sizes/weights are locked in
/// one place.
abstract final class AppTypography {
  static const TextStyle display = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    color: AppColors.textSecondary,
  );
}
