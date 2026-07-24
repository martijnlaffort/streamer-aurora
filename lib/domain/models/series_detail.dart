import 'package:equatable/equatable.dart';

import 'episode.dart';
import 'season.dart';
import 'series.dart';

/// Aggregate returned by `PlaylistSource.getSeriesInfo`: one series with its
/// seasons and all episodes (PRD §6.1 get_series_info).
class SeriesDetail extends Equatable {
  const SeriesDetail({
    required this.series,
    required this.seasons,
    required this.episodes,
  });

  final Series series;

  /// Sorted by season number.
  final List<Season> seasons;

  /// All episodes across seasons, sorted by (season, episode) number.
  final List<Episode> episodes;

  List<Episode> episodesOfSeason(int seasonNumber) =>
      episodes.where((e) => e.seasonNumber == seasonNumber).toList();

  @override
  List<Object?> get props => [series, seasons, episodes];

  @override
  bool get stringify => true;
}
