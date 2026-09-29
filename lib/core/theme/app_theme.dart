import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// The app's themes (PRD §10) — content is the hero, chrome recedes.
///
/// Dark remains the default and the design of record; light is built from the
/// same function against a different [DawnPalette], so the two cannot drift
/// apart as the theme grows.
abstract final class AppTheme {
  static ThemeData get dark => darkFor(tv: false);

  static ThemeData get light => lightFor(tv: false);

  /// [tv] adds the remote's cursor to every Material button and chip; see
  /// [_tvFocus].
  static ThemeData darkFor({required bool tv}) =>
      _build(DawnPalette.dark, Brightness.dark, tv: tv);

  static ThemeData lightFor({required bool tv}) =>
      _build(DawnPalette.light, Brightness.light, tv: tv);

  static ThemeData _build(DawnPalette p, Brightness brightness,
      {required bool tv}) {
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

    // Inter is bundled (see pubspec), so the UI face is applied by family
    // name; nothing is fetched at runtime.
    final textTheme =
        base.textTheme.apply(fontFamily: AppTypography.uiFamily).copyWith(
      displayLarge: AppTypography.display.copyWith(color: p.textPrimary),
      headlineMedium:
          AppTypography.display.copyWith(fontSize: 28, color: p.textPrimary),
      titleLarge: AppTypography.title.copyWith(color: p.textPrimary),
      bodyMedium: AppTypography.body.copyWith(color: p.textPrimary),
      labelMedium: AppTypography.label.copyWith(color: p.textSecondary),
    );

    final themed = base.copyWith(
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
          textStyle: const TextStyle(
              fontFamily: AppTypography.uiFamily,
              fontWeight: FontWeight.w600),
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
    return tv ? _tvFocus(themed, p) : themed;
  }

  /// The remote's cursor on every Material button and chip.
  ///
  /// Material 3 buttons ignore [ThemeData.focusColor] and mark focus with a
  /// tint of about 10% — from a sofa, no cursor at all. That covered the back
  /// arrows, app-bar actions, "See all", dialog buttons and chips: most of
  /// "I can't tell where my cursor is". Icon buttons invert (a solid disc in
  /// the focus colour), the way the player's transport already did; everything
  /// else gets a solid ring, like the poster cards.
  ///
  /// Television only. A button is "focused" under touch too — a dialog's
  /// autofocused action, say — and a ring there would read as selected.
  /// Explicit per-widget styles still win over these.
  static ThemeData _tvFocus(ThemeData t, DawnPalette p) {
    bool focused(Set<WidgetState> s) => s.contains(WidgetState.focused);
    final ring = BorderSide(color: p.focusRing, width: 3);
    final side = WidgetStateProperty.resolveWith<BorderSide?>(
        (s) => focused(s) ? ring : null);
    ButtonStyle ringed(ButtonStyle? style) =>
        (style ?? const ButtonStyle()).copyWith(side: side);
    // On the dark palette the ring is white, so the glyph on it goes dark; on
    // the light one the ring is the accent, and the glyph goes white.
    final onRing = t.brightness == Brightness.dark
        ? p.background
        : const Color(0xFFFFFFFF);
    return t.copyWith(
      textButtonTheme:
          TextButtonThemeData(style: ringed(t.textButtonTheme.style)),
      filledButtonTheme:
          FilledButtonThemeData(style: ringed(t.filledButtonTheme.style)),
      outlinedButtonTheme:
          OutlinedButtonThemeData(style: ringed(t.outlinedButtonTheme.style)),
      elevatedButtonTheme:
          ElevatedButtonThemeData(style: ringed(t.elevatedButtonTheme.style)),
      iconButtonTheme: IconButtonThemeData(
        style: (t.iconButtonTheme.style ?? const ButtonStyle()).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
              (s) => focused(s) ? p.focusRing : null),
          foregroundColor:
              WidgetStateProperty.resolveWith((s) => focused(s) ? onRing : null),
          iconColor:
              WidgetStateProperty.resolveWith((s) => focused(s) ? onRing : null),
        ),
      ),
      chipTheme: t.chipTheme.copyWith(
        side: WidgetStateBorderSide.resolveWith((s) => focused(s) ? ring : null),
      ),
    );
  }
}
