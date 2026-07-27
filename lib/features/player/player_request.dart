import '../../domain/models/models.dart';

/// One playable thing in the player's queue.
class PlayerItem {
  const PlayerItem({
    required this.streamRef,
    required this.title,
    required this.contentKey,
    this.subtitle,
    this.isLive = false,
  });

  final StreamRef streamRef;
  final String title;

  /// Secondary line, e.g. "S1 · E2 — The Meadow" or the now-playing programme.
  final String? subtitle;

  /// Watch-progress identity for this item.
  final String contentKey;

  /// Live streams have no meaningful duration: the player hides the seek bar,
  /// shows a LIVE badge, and skips resume/progress tracking.
  final bool isLive;
}

/// What a detail screen hands the player route: a queue (a single movie, or
/// a series' episodes for autoplay-next) plus where to start.
class PlayerRequest {
  const PlayerRequest({
    required this.queue,
    this.startIndex = 0,
    this.resumeFromSeconds,
  }) : assert(queue.length > 0);

  final List<PlayerItem> queue;
  final int startIndex;

  /// Non-null → seek here once the media reports a duration (PRD §8.9).
  final int? resumeFromSeconds;

  PlayerItem get startItem => queue[startIndex];
}
