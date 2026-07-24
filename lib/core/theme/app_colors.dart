import 'package:flutter/painting.dart';

/// Placeholder dark-cinematic palette per PRD §10. These are design *tokens*:
/// the real values get tuned in the visual pass (Task 1.8) — change them here,
/// nowhere else.
abstract final class AppColors {
  /// Near-black with a blue cast; the app's canvas.
  static const Color background = Color(0xFF0B0D12);

  /// Cards, sheets, and rails sit on this.
  static const Color surface = Color(0xFF12151C);

  /// Hovered/raised surfaces (dialogs, focused cards).
  static const Color surfaceElevated = Color(0xFF1A1E27);

  /// Primary accent — "aurora" violet (placeholder).
  static const Color accent = Color(0xFF7C5CFF);

  /// Secondary accent — teal glow (placeholder).
  static const Color accentAlt = Color(0xFF4FD1C5);

  static const Color textPrimary = Color(0xFFF2F4F8);
  static const Color textSecondary = Color(0xFF9AA3B2);

  /// Focus ring for the TV/D-pad layer later; white reads on any artwork.
  static const Color focusRing = Color(0xFFFFFFFF);

  static const Color error = Color(0xFFFF5C6C);

  /// Bottom-up scrim to keep text legible over artwork (hero, rails).
  static const Gradient scrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x000B0D12), Color(0xCC0B0D12), Color(0xFF0B0D12)],
  );
}
