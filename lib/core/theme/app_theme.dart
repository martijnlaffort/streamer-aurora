import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// The app's themes (PRD §10) — content is the hero, chrome recedes.
///
/// Dark remains the default and the design of record; light is built from the
/// same function against a different [DawnPalette], so the two cannot drift
/// apart as the theme grows.
abstract final class AppTheme {
  static ThemeData get dark => _build(DawnPalette.dark, Brightness.dark);

  static ThemeData get light => _build(DawnPalette.light, Brightness.light);

  static ThemeData _build(DawnPalette p, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.accent,
        onPrimary: brightness == Brightness.dark
            ? p.textPrimary
            : const Color(0xFFFFFFFF),
        secondary: p.accentAlt,
        onSecondary: brightness == Brightness.dark
            ? p.textPrimary
            : const Color(0xFFFFFFFF),
        surface: p.surface,
        onSurface: p.textPrimary,
        surfaceContainerHighest: p.surfaceElevated,
        error: p.error,
        onError: const Color(0xFFFFFFFF),
      ),
      scaffoldBackgroundColor: p.background,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: AppTypography.display.copyWith(color: p.textPrimary),
      headlineMedium:
          AppTypography.display.copyWith(fontSize: 28, color: p.textPrimary),
      titleLarge: AppTypography.title.copyWith(color: p.textPrimary),
      bodyMedium: AppTypography.body.copyWith(color: p.textPrimary),
      labelMedium: AppTypography.label.copyWith(color: p.textSecondary),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: p.textPrimary,
        titleTextStyle: AppTypography.title.copyWith(color: p.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        height: 68,
        indicatorColor: p.accent.withValues(alpha: 0.24),
        labelTextStyle: WidgetStatePropertyAll(
            AppTypography.label.copyWith(fontSize: 11, color: p.textSecondary)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceElevated,
        contentTextStyle: TextStyle(color: p.textPrimary),
      ),
      // The app-wide cursor for a remote. Material's default focus tint is ~10%
      // of the foreground, which on either palette is too faint to find from a
      // sofa; one strong value here covers every plain row in the app at once.
      // Surfaces that draw their own (poster cards, the player transport) opt
      // out with `focusColor: Colors.transparent`.
      focusColor: p.accent.withValues(alpha: brightness == Brightness.dark ? 0.38 : 0.24),
      hoverColor: p.accent.withValues(alpha: 0.12),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
