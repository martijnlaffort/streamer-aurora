import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Dark cinematic theme per PRD §10 — content is the hero, chrome recedes.
/// Dark is the only theme; there is deliberately no light variant.
abstract final class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentAlt,
        surface: AppColors.surface,
        surfaceContainerHighest: AppColors.surfaceElevated,
        onPrimary: AppColors.textPrimary,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: AppTypography.display,
        titleLarge: AppTypography.title,
        bodyMedium: AppTypography.body,
        labelMedium: AppTypography.label,
      ),
    );
  }
}
