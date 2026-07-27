import '../../domain/models/models.dart';

/// Thrown by sources for anything the caller should surface: bad credentials,
/// unreachable panel, malformed top-level responses. Per-row catalog junk is
/// NOT an exception — bad rows are skipped and logged (global rule).
class SourceException implements Exception {
  const SourceException(this.message, [this.cause]);

  /// Human-readable, safe to show in UI.
  final String message;
  final Object? cause;

  @override
  String toString() =>
      cause == null ? 'SourceException: $message' : 'SourceException: $message ($cause)';
}

/// The backbone abstraction (PRD §5): Xtream and M3U both normalize into the
/// same domain models behind this interface, so everything above it is
/// source-agnostic.
abstract interface class PlaylistSource {
  /// Validates the account against the panel. Completes normally when the
  /// account is usable; throws [SourceException] with a displayable reason
  /// (invalid credentials, expired, unreachable) otherwise.
  Future<void> authenticate();

  Future<List<Category>> getLiveCategories();

  Future<List<Channel>> getLiveStreams({String? categoryId});

  Future<List<Category>> getVodCategories();

  Future<List<Movie>> getVodStreams({String? categoryId});

  /// Detail lookup (plot, cast, backdrop, duration...) for one VOD item.
  Future<Movie> getVodInfo(String vodId);

  Future<List<Category>> getSeriesCategories();

  Future<List<Series>> getSeries({String? categoryId});

  /// Seasons + episodes for one series.
  Future<SeriesDetail> getSeriesInfo(String seriesId);

  /// Now/next (or a few upcoming entries) for a live stream.
  Future<List<EpgEntry>> getShortEpg(String streamId, {int limit = 4});

  /// Builds the playable URL for [ref] per the source's URL scheme
  /// (PRD §6.1 for Xtream). The UI never assembles URLs itself. Async because
  /// M3U must resolve the id against its playlist, loading it if needed.
  Future<String> buildStreamUrl(StreamRef ref);
}
