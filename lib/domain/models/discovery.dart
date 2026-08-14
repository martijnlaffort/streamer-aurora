import 'package:equatable/equatable.dart';

/// Which catalogue slice a discovery list resolves against.
enum DiscoveryKind { movie, series }

/// One entry of an external ranked list (TMDB trending/popular/top-rated, or
/// the bundled award canon). This is *not* a catalogue row — it is a title we
/// know is worth surfacing, which may or may not exist in the user's playlist.
class DiscoveryTitle extends Equatable {
  const DiscoveryTitle({
    required this.title,
    required this.rank,
    this.tmdbId,
    this.year,
    this.voteAverage,
    this.voteCount,
  });

  final String title;

  /// Position in the source list — the ranking we want to preserve, since it
  /// already encodes popularity/acclaim far better than a panel's rating.
  final int rank;

  /// Null for bundled canon entries, which predate any TMDB lookup.
  final int? tmdbId;
  final int? year;
  final double? voteAverage;
  final int? voteCount;

  @override
  List<Object?> get props => [title, rank, tmdbId, year, voteAverage, voteCount];
}

/// A discovery list definition: its stable id, the rail heading, and which
/// slice it resolves against.
class DiscoveryList {
  const DiscoveryList({
    required this.id,
    required this.label,
    required this.kind,
    required this.needsApiKey,
    this.numbered = false,
  });

  final String id;
  final String label;
  final DiscoveryKind kind;

  /// Bundled lists (the award canon) work with no key and no network.
  final bool needsApiKey;

  /// Render as a numbered Top 10. Netflix's Top 10 row exists as social proof —
  /// a rank is a much stronger signal than another unlabelled poster — and this
  /// list is already region-scoped, so the ranking means something local.
  final bool numbered;
}

/// The catalogue-resolved form of a list: the titles the user can actually
/// play, in the source list's order.
class DiscoveryRail<T> {
  const DiscoveryRail({
    required this.label,
    required this.items,
    this.numbered = false,
  });

  final String label;
  final List<T> items;
  final bool numbered;
}
