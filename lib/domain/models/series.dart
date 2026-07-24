import 'package:equatable/equatable.dart';

/// A series (show) as listed in the catalog (PRD §7 `series`). Seasons and
/// episodes hang off it via [Season]/[Episode], fetched on demand.
class Series extends Equatable {
  const Series({
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
    this.genre,
    this.cast,
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

  /// Freeform, as panels provide it ("Drama").
  final String? genre;

  /// Freeform comma-separated names.
  final String? cast;

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
        genre,
        cast,
        cachedAt,
      ];

  @override
  bool get stringify => true;
}
