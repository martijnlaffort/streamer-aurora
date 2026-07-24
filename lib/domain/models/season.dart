import 'package:equatable/equatable.dart';

/// One season of a [Series] (from Xtream `get_series_info`).
class Season extends Equatable {
  const Season({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    this.name,
    this.posterUrl,
    this.episodeCount,
  });

  final String id;
  final String seriesId;
  final int seasonNumber;
  final String? name;
  final String? posterUrl;
  final int? episodeCount;

  @override
  List<Object?> get props =>
      [id, seriesId, seasonNumber, name, posterUrl, episodeCount];

  @override
  bool get stringify => true;
}
