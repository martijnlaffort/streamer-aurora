import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether Dawn Player is running on a television, which selects the D-pad /
/// 10-foot UI (PRD Phase 3).
///
/// Answered by the platform (`UiModeManager`), not guessed from screen size:
/// a tablet and the Windows desktop build are just as large as a TV, so a size
/// heuristic would put the wrong shell on the wrong device.
const _channel = MethodChannel('dawnplayer/platform');

/// Debug-only override so the TV shell can be exercised on a phone emulator —
/// a TV system image is a multi-gigabyte download, and the parts most likely to
/// be wrong (focus traversal, remote activation) are testable with
/// `adb shell input keyevent KEYCODE_DPAD_*` on any device.
///
/// Set with `--dart-define=DAWN_FORCE_TV=true`. Ignored in release builds so
/// it can never ship a TV layout to a phone.
const _forceTvFlag =
    bool.fromEnvironment('DAWN_FORCE_TV', defaultValue: false);

Future<bool> detectTelevision() async {
  if (!kReleaseMode && _forceTvFlag) return true;
  if (!Platform.isAndroid) return false;
  try {
    return await _channel.invokeMethod<bool>('isTelevision') ?? false;
  } on PlatformException {
    return false; // Older build without the channel — assume handheld.
  } on MissingPluginException {
    return false;
  }
}

/// Resolved once at startup; the device does not change shape mid-session.
final isTelevisionProvider =
    FutureProvider<bool>((ref) => detectTelevision());

/// Synchronous access for widgets that cannot await. Defaults to `false` until
/// detection resolves, so the handheld layout is what shows for the first frame
/// — the safe direction to be wrong in, since a TV corrects itself immediately.
bool isTelevisionOf(WidgetRef ref) =>
    ref.watch(isTelevisionProvider).value ?? false;

/// Padding that keeps content clear of a TV's overscan area. Televisions crop
/// the outer few percent of the signal, so edge-anchored UI can be physically
/// off-screen on a real set even though it looks fine in an emulator.
const tvOverscan = EdgeInsets.symmetric(horizontal: 32, vertical: 24);
