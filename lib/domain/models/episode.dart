import 'package:equatable/equatable.dart';

/// One episode of a [Series] (PRD §7 `episodes`).
class Episode extends Equatable {
  const Episode({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    required this.cachedAt,
    this.plot,
    this.durationSeconds,
    this.stillUrl,
    this.containerExt,
    this.airDate,
  });

  final String id;
  final String seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String title;
  final String? plot;
  final int? durationSeconds;

  /// Episode still/thumbnail.
  final String? stillUrl;

  /// Xtream `container_extension` — needed to build the stream URL (PRD §6.1).
  final String? containerExt;

  /// UTC.
  final DateTime? airDate;

  /// When this row was cached locally (UTC) — drives the cache TTL.
  final DateTime cachedAt;

  @override
  List<Object?> get props => [
        id,
        seriesId,
        seasonNumber,
        episodeNumber,
        title,
        plot,
        durationSeconds,
        stillUrl,
        containerExt,
        airDate,
        cachedAt,
      ];

  @override
  bool get stringify => true;
}
