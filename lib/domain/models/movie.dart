import 'package:equatable/equatable.dart';

/// A VOD title (PRD §7 `movies`). Every metadata field a panel can omit is
/// nullable — defensive parsing is the source's job, absence is normal here.
class Movie extends Equatable {
  const Movie({
    required this.id,
    required this.accountId,
    required this.categoryId,
    required this.name,
    required this.cachedAt,
    this.posterUrl,
    this.backdropUrl,
    this.rating,
    this.year,
    this.plot,
    this.durationSeconds,
    this.containerExt,
    this.addedAt,
  });

  final String id;
  final String accountId;
  final String categoryId;
  final String name;
  final String? posterUrl;
  final String? backdropUrl;
  final double? rating;
  final int? year;
  final String? plot;
  final int? durationSeconds;

  /// Xtream `container_extension` — needed to build the stream URL (PRD §6.1).
  final String? containerExt;

  /// When the panel added it (UTC) — drives "Recently Added".
  final DateTime? addedAt;

  /// When this row was cached locally (UTC) — drives the cache TTL.
  final DateTime cachedAt;

  @override
  List<Object?> get props => [
        id,
        accountId,
        categoryId,
        name,
        posterUrl,
        backdropUrl,
        rating,
        year,
        plot,
        durationSeconds,
        containerExt,
        addedAt,
        cachedAt,
      ];

  @override
  bool get stringify => true;
}
