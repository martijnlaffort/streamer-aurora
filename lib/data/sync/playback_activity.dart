import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a video is on screen right now.
///
/// Sync itself is tiny, but the catalogue *backfill* it triggers is not: it can
/// fetch a couple of dozen `get_series_info` / `get_vod_info` responses, and a
/// long-running series is a large one. Doing that behind a playing video
/// competes with the stream for the same connection and shows up as buffering.
/// The player registers here for its lifetime so background catch-up can wait
/// until the screen is free (see [whenIdle]).
///
/// A counter rather than a bool: the player can be rebuilt or briefly overlap
/// itself (queue advance, a reopened route), and a plain flag would be cleared
/// by the first dispose while a second player was still on screen.
class PlaybackActivity {
  int _active = 0;
  Completer<void>? _idle;

  bool get isPlaying => _active > 0;

  void enter() => _active++;

  void leave() {
    if (_active > 0) _active--;
    if (_active == 0) {
      _idle?.complete();
      _idle = null;
    }
  }

  /// Completes at once when nothing is playing, otherwise when the last player
  /// closes. For downloads that can wait: the catalogue's stale-while-refresh
  /// updates and the full TV-guide download. They used to run behind a playing
  /// video — the guide is often hundreds of megabytes — and competed with the
  /// stream for the same connection and CPU, which shows up as buffering.
  ///
  /// Never await this from anything the player itself waits on.
  Future<void> whenIdle() {
    if (_active == 0) return Future<void>.value();
    return (_idle ??= Completer<void>()).future;
  }
}

final playbackActivityProvider = Provider<PlaybackActivity>((ref) {
  return PlaybackActivity();
});
