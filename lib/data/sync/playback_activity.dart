import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a video is on screen right now.
///
/// Sync itself is tiny, but the catalogue *backfill* it triggers is not: it can
/// fetch a couple of dozen `get_series_info` / `get_vod_info` responses, and a
/// long-running series is a large one. Doing that behind a playing video
/// competes with the stream for the same connection and shows up as buffering.
/// The player registers here for its lifetime so background catch-up can wait
/// until the screen is free.
///
/// A counter rather than a bool: the player can be rebuilt or briefly overlap
/// itself (queue advance, a reopened route), and a plain flag would be cleared
/// by the first dispose while a second player was still on screen.
class PlaybackActivity {
  int _active = 0;

  bool get isPlaying => _active > 0;

  void enter() => _active++;

  void leave() {
    if (_active > 0) _active--;
  }
}

final playbackActivityProvider = Provider<PlaybackActivity>((ref) {
  return PlaybackActivity();
});
