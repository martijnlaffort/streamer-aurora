import 'package:flutter/painting.dart';

/// One complete set of the app's semantic colours.
///
/// The app names colours by ROLE (`background`, `surfaceElevated`, `accent`)
/// rather than by value, which is what makes a second palette possible at all:
/// there are ~250 references across the app but only ten roles, so a light
/// theme is a second instance of this class rather than a rewrite.
class DawnPalette {
  const DawnPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.accent,
    required this.accentAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.focusRing,
    required this.error,
    required this.scrim,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color accent;
  final Color accentAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color focusRing;
  final Color error;
  final Gradient scrim;

  /// The original cinematic dark theme (PRD §10) — still the default.
  static const dark = DawnPalette(
    background: Color(0xFF0B0D12),
    surface: Color(0xFF12151C),
    surfaceElevated: Color(0xFF1A1E27),
    accent: Color(0xFF7C5CFF),
    accentAlt: Color(0xFF4FD1C5),
    textPrimary: Color(0xFFF2F4F8),
    textSecondary: Color(0xFF9AA3B2),
    // White reads on any artwork.
    focusRing: Color(0xFFFFFFFF),
    error: Color(0xFFFF5C6C),
    scrim: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x000B0D12), Color(0xCC0B0D12), Color(0xFF0B0D12)],
    ),
  );

  /// Light theme. The accents are unchanged so the app still looks like itself;
  /// only the ground and the type invert.
  static const light = DawnPalette(
    // Not pure white: a full-white ground under a poster wall is glaring, and
    // the faint blue cast keeps the family resemblance to the dark theme.
    background: Color(0xFFF5F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFE8EBF2),
    accent: Color(0xFF6B49F5),
    // Darkened from the dark theme's teal, which fails contrast on white.
    accentAlt: Color(0xFF0F8F84),
    textPrimary: Color(0xFF11141B),
    textSecondary: Color(0xFF5B6474),
    // NOT white here — the ring sits on pale surfaces as often as on artwork,
    // and a white ring on a white card is no ring at all. The accent reads on
    // both.
    focusRing: Color(0xFF6B49F5),
    error: Color(0xFFC62839),
    // The scrim stays DARK in both themes: it exists to hold white text over a
    // photograph, and a photograph is dark-ish whatever the app around it does.
    scrim: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x00000000), Color(0x99000000), Color(0xE6000000)],
    ),
  );
}

/// The colours in force right now.
///
/// Deliberately a swappable global rather than a `ThemeExtension` read from
/// `context`: the roles are referenced from ~250 places including providers and
/// helpers that have no `BuildContext`, and threading one through all of them
/// would be a far larger and riskier change than this app warrants.
///
/// The trade-off is that these are getters, so they cannot be used in `const`
/// expressions — which is also what makes a theme switch take effect, since a
/// `const` widget would never rebuild to pick up the new value.
abstract final class AppColors {
  /// The active palette. Set before the app builds, and again when the
  /// preference changes.
  static DawnPalette palette = DawnPalette.dark;

  static DawnPalette get _palette => palette;

  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get surfaceElevated => _palette.surfaceElevated;
  static Color get accent => _palette.accent;
  static Color get accentAlt => _palette.accentAlt;
  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get focusRing => _palette.focusRing;
  static Color get error => _palette.error;
  static Gradient get scrim => _palette.scrim;
}
