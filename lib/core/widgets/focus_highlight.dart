import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Makes it unmistakable which control the remote is on.
///
/// Material's own focus overlay is a faint colour wash — on this near-black
/// theme, from a sofa, it is effectively invisible, which is why the detail
/// screens felt like they had no cursor at all. This wraps any control in the
/// same affordance the poster cards use: a bright ring plus an accent glow, and
/// a slight pop.
///
/// It does NOT take focus itself ([Focus.canRequestFocus] is false) — it only
/// observes whether focus is anywhere inside it, so wrapping a button never
/// changes the traversal order. Hover is included so a mouse gets the same
/// feedback on desktop.
class FocusHighlight extends StatefulWidget {
  const FocusHighlight({
    super.key,
    required this.child,
    this.borderRadius = 12,
    this.scale = 1.04,
    this.ensureVisible = false,
  });

  final Widget child;

  /// Match the wrapped control's own radius so the ring hugs it.
  final double borderRadius;

  /// Set to 1.0 for controls inside a tight row where growing would shift the
  /// layout (the ring and glow alone are enough there).
  final double scale;

  /// Scroll the control into view when it takes focus — for anything inside a
  /// scrollable, otherwise the D-pad can walk focus off-screen.
  final bool ensureVisible;

  @override
  State<FocusHighlight> createState() => _FocusHighlightState();
}

class _FocusHighlightState extends State<FocusHighlight> {
  bool _engaged = false;

  void _set(bool value) {
    if (_engaged == value || !mounted) return;
    setState(() => _engaged = value);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    return MouseRegion(
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: Focus(
        canRequestFocus: false,
        onFocusChange: (focused) {
          _set(focused);
          if (focused && widget.ensureVisible) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.5,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
            );
          }
        },
        child: AnimatedScale(
          scale: _engaged ? widget.scale : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: _engaged
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.55),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            // Drawn in FRONT so the ring never insets or reflows the child.
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: _engaged ? AppColors.focusRing : Colors.transparent,
                width: 3,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
