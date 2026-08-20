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

/// Where a live channel sits in the list the user was browsing, so the player
/// can offer channel up/down.
///
/// Carries the *scope* and a position rather than the channels themselves: the
/// list is 25k entries on a real line, and the player resolves neighbours one
/// indexed row at a time (`CatalogRepository.channelAt`).
class ZapContext {
  const ZapContext({
    required this.index,
    this.categoryId,
    this.categoryIds,
  });

  /// Position of the playing channel within the scoped, sorted list.
  final int index;

  /// The category the user had selected, or null for "all channels".
  final String? categoryId;

  /// The content-language filter's allowed categories, when no explicit
  /// category is selected. Null means unfiltered.
  final Set<String>? categoryIds;

  ZapContext withIndex(int next) => ZapContext(
        index: next,
        categoryId: categoryId,
        categoryIds: categoryIds,
      );
}

/// What a detail screen hands the player route: a queue (a single movie, or
/// a series' episodes for autoplay-next) plus where to start.
class PlayerRequest {
  const PlayerRequest({
    required this.queue,
    this.startIndex = 0,
    this.resumeFromSeconds,
    this.zap,
  }) : assert(queue.length > 0);

  final List<PlayerItem> queue;
  final int startIndex;

  /// Set for live playback launched from a channel list — enables zapping.
  final ZapContext? zap;

  /// Non-null → seek here once the media reports a duration (PRD §8.9).
  final int? resumeFromSeconds;

  /// Clamped so a stale or `-1` index (e.g. an episode that fell out of a
  /// refreshed list) can never throw — it just starts from the nearest valid
  /// item instead.
  PlayerItem get startItem => queue[startIndex.clamp(0, queue.length - 1)];
}
