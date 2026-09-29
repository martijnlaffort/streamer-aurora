import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';

import 'television.dart';

/// Which way the app may turn, and the landscape lock the players take.
///
/// A phone is a portrait app with a landscape player, the way Netflix and HBO
/// are. The players used to "restore" by allowing every orientation, which on a
/// phone held sideways kept the app sideways after the film — and on iOS, which
/// only rotates when the current orientation stops being allowed, kept it
/// sideways until the phone was physically turned. Restoring means asking for
/// portrait by name.
///
/// Mobile only: on the desktop these calls can pin the window to a broken size.
/// A television runs Android too, but has no orientation to choose, so it is
/// left alone entirely — and must be, because a 1080p set is about 540 logical
/// pixels on its short side and would otherwise pass for a phone.
bool get _isMobile => Platform.isAndroid || Platform.isIOS;

final Future<bool> _onTelevision = detectTelevision();

/// Below this shortest side (logical pixels) a device is a phone and stays in
/// portrait outside the player; at or above it, a tablet turns freely.
const _tabletShortestSide = 600.0;

Future<List<DeviceOrientation>?> _appOrientations() async {
  if (!_isMobile || await _onTelevision) return null;
  final view = PlatformDispatcher.instance.implicitView;
  // No metrics yet (first frame not laid out): allow everything rather than
  // guess, so a tablet is never pinned to portrait by a zero size.
  if (view == null || view.physicalSize.isEmpty) {
    return DeviceOrientation.values;
  }
  final shortest = view.physicalSize.shortestSide / view.devicePixelRatio;
  return shortest < _tabletShortestSide
      ? const [DeviceOrientation.portraitUp]
      : DeviceOrientation.values;
}

/// Puts the app in its normal orientation. Called at startup and whenever the
/// last landscape screen closes.
Future<void> applyAppOrientation() async {
  final orientations = await _appOrientations();
  if (orientations == null) return;
  await SystemChrome.setPreferredOrientations(orientations);
}

/// Fullscreen landscape for as long as it is held.
///
/// Counted, because players can stack — a reminder opens a second player on top
/// of one already playing — and the one underneath must not be rotated back to
/// portrait when the top one closes. [release] is idempotent so it can be
/// called both when the route pops (so the screen underneath comes back upright
/// instead of sliding in sideways) and again from `dispose` as a safety net.
class LandscapeLock {
  LandscapeLock._();

  static int _held = 0;
  bool _released = false;

  /// Takes the lock, or returns null where orientation is not the app's to set.
  static LandscapeLock? acquire() {
    if (!_isMobile) return null;
    _held++;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    return LandscapeLock._();
  }

  void release() {
    if (_released) return;
    _released = true;
    _held--;
    if (_held > 0) return;
    _held = 0;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    applyAppOrientation();
  }
}
