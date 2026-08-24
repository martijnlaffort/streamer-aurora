import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: AppTypography.display,
      headlineMedium: AppTypography.display.copyWith(fontSize: 28),
      titleLarge: AppTypography.title,
      bodyMedium: AppTypography.body,
      labelMedium: AppTypography.label,
    );

    return base.copyWith(
      textTheme: textTheme,
      // The app-wide cursor for a remote.
      //
      // Material's default focus tint is ~10% white, which on this near-black
      // palette is invisible from a sofa — so every plain row (Settings, the
      // account list, search results, the favourites list) looked identical
      // whether or not the D-pad was on it. One strong value here gives every
      // InkWell and ListTile in the app an obvious highlight, which is far more
      // reliable than remembering to decorate each one. Individually styled
      // surfaces (poster cards, the player transport) opt out by setting
      // `focusColor: Colors.transparent` and drawing their own.
      focusColor: AppColors.accent.withValues(alpha: 0.38),
      hoverColor: AppColors.accent.withValues(alpha: 0.12),
      listTileTheme: ListTileThemeData(
        // A rounded highlight rather than a full-bleed band: it reads as a
        // selected item instead of a coloured stripe across the screen.
        // (ListTile picks the colour up from ThemeData.focusColor above.)
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: AppTypography.title,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        height: 68,
        indicatorColor: AppColors.accent.withValues(alpha: 0.24),
        labelTextStyle: WidgetStatePropertyAll(
            AppTypography.label.copyWith(fontSize: 11)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
      ),
    );
  }
}
