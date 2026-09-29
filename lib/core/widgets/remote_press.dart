import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A remote's OK that can tell a press from a hold.
///
/// Flutter turns OK's key-DOWN into an activation at once, so a widget never
/// learns the button is being held: every long-press action in the app was
/// unreachable with a remote, and cards with a second action (Continue
/// Watching) opened a menu on EVERY OK instead of doing the obvious thing.
/// This decides on key-UP: a short press is [onPressed], holding for half a
/// second is [onLongPress] — the convention Google TV's own launcher uses.
///
/// Wraps a focusable child (an InkWell, a card) without taking focus itself,
/// and only claims OK keys while [enabled]; touch, mouse and every other key
/// are untouched. Pass `enabled: isTelevisionOf(ref)`.
class RemotePress extends StatefulWidget {
  const RemotePress({
    super.key,
    required this.enabled,
    required this.onPressed,
    required this.onLongPress,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;
  final Widget child;

  @override
  State<RemotePress> createState() => _RemotePressState();
}

class _RemotePressState extends State<RemotePress> {
  static const _holdFor = Duration(milliseconds: 500);

  Timer? _hold;

  /// Whether the DOWN of the current press reached us. An UP on its own (the
  /// press started somewhere else, then focus moved here) is not a press.
  bool _down = false;

  static bool _isOk(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.gameButtonA;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled || !_isOk(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    switch (event) {
      case KeyDownEvent():
        _down = true;
        _hold?.cancel();
        _hold = Timer(_holdFor, () {
          _down = false;
          widget.onLongPress();
        });
      case KeyRepeatEvent():
        break; // Still held; the timer decides.
      case KeyUpEvent():
        final wasPress = _down && (_hold?.isActive ?? false);
        _hold?.cancel();
        _down = false;
        if (wasPress) widget.onPressed();
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: widget.child,
      );
}
