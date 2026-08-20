import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/models/models.dart';
import 'json_values.dart';
import 'm3u_parser.dart';
import 'playlist_source.dart';

/// M3U playlist source (PRD §6.2), producing the SAME domain models as
/// [XtreamSource] so everything above the [PlaylistSource] seam is oblivious
/// to where the catalog came from.
///
/// - `group-title` → categories (per type).
/// - Live vs VOD is split on the URL's file extension (`.mp4`/`.mkv`/... →
///   movie) — the naming-convention reality of mixed playlists. Series are
///   not derivable from plain M3U; those calls return empty/throw.
/// - [epgUrl] (explicit, or `url-tvg` from the playlist header) is accepted
///   and stored; XMLTV ingestion itself lands with the EPG repository, so
///   [getShortEpg] currently returns no entries.
class M3uSource implements PlaylistSource {
  M3uSource({
    required this.account,
    this.epgUrl,
    Dio? dio,
    DateTime Function()? clock,
    void Function(String message)? onSkippedRow,
  })  : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 60),
        )),
        _clock = clock ?? (() => DateTime.now().toUtc()),
        _onSkippedRow =
            onSkippedRow ?? ((m) => developer.log(m, name: 'M3uSource'));

  /// `account.serverUrl` is the playlist URL (http/https) or a local file path.
  final Account account;

  /// Optional XMLTV EPG URL configured alongside the playlist.
  final String? epgUrl;

  final Dio _dio;
  final DateTime Function() _clock;
  final void Function(String message) _onSkippedRow;

  @override
  bool get supportsCategoryFetch => false;

  static const _vodExtensions = {'mp4', 'mkv', 'avi', 'mov', 'webm', 'flv'};
  static const _uncategorized = 'Uncategorized';

  M3uPlaylist? _playlist;

  /// EPG URL that ends up effective: the explicit one wins over the
  /// playlist header's `url-tvg`. Meaningful after the playlist is loaded.
  String? get effectiveEpgUrl => epgUrl ?? _playlist?.epgUrl;

  Future<M3uPlaylist> _load() async {
    final cached = _playlist;
    if (cached != null) return cached;

    final location = account.serverUrl.trim();
    final String text;
    try {
      if (location.startsWith('http://') || location.startsWith('https://')) {
        final response = await _dio.get<String>(
          location,
          options: Options(responseType: ResponseType.plain),
        );
        text = response.data ?? '';
      } else {
        text = await File(location).readAsString();
      }
    } on DioException catch (e) {
      throw SourceException('Could not fetch the playlist: ${e.message}', e);
    } on FileSystemException catch (e) {
      throw SourceException('Could not read the playlist file', e);
    }

    final playlist = parseM3u(text, onSkippedLine: _onSkippedRow);
    if (!playlist.sawHeader && playlist.entries.isEmpty) {
      throw const SourceException('Not a valid M3U playlist');
    }
    _playlist = playlist;
    return playlist;
  }

  bool _isVod(M3uEntry entry) =>
      _vodExtensions.contains(_extensionOf(entry.url));

  String? _extensionOf(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return null;
    final ext = path.substring(dot + 1).toLowerCase();
    return ext.length <= 4 ? ext : null;
  }

  Future<List<M3uEntry>> _entriesOf({required bool vod}) async =>
      (await _load()).entries.where((e) => _isVod(e) == vod).toList();

  // --- PlaylistSource --------------------------------------------------------

  @override
  Future<void> authenticate() async {
    final playlist = await _load();
    if (playlist.entries.isEmpty) {
      throw const SourceException('Playlist contains no entries');
    }
  }

  Future<List<Category>> _categoriesOf(CategoryType type,
      {required bool vod}) async {
    final seen = <String>{};
    final result = <Category>[];
    for (final entry in await _entriesOf(vod: vod)) {
      final group = entry.groupTitle ?? _uncategorized;
      if (seen.add(group)) {
        result.add(Category(
          id: group,
          accountId: account.id,
          type: type,
          name: group,
          sortOrder: result.length,
        ));
      }
    }
    return result;
  }

  @override
  Future<List<Category>> getLiveCategories() =>
      _categoriesOf(CategoryType.live, vod: false);

  @override
  Future<List<Category>> getVodCategories() =>
      _categoriesOf(CategoryType.vod, vod: true);

  @override
  Future<List<Channel>> getLiveStreams({String? categoryId}) async {
    final now = _clock();
    final result = <Channel>[];
    for (final (index, entry) in (await _entriesOf(vod: false)).indexed) {
      final group = entry.groupTitle ?? _uncategorized;
      if (categoryId != null && group != categoryId) continue;
      result.add(Channel(
        id: stableId(entry.url),
        accountId: account.id,
        categoryId: group,
        name: entry.name,
        logoUrl: entry.tvgLogo,
        epgChannelId: entry.tvgId,
        sortOrder: index,
        cachedAt: now,
      ));
    }
    return result;
  }

  Movie _movieFrom(M3uEntry entry, String group, DateTime now) => Movie(
        id: stableId(entry.url),
        accountId: account.id,
        categoryId: group,
        name: entry.name,
        posterUrl: entry.tvgLogo,
        // M3U carries no year/plot/rating — the UI degrades gracefully.
        year: optYear(RegExp(r'\((19|20)\d\d\)')
            .firstMatch(entry.name)
            ?.group(0)
            ?.replaceAll(RegExp(r'[()]'), '')),
        containerExt: _extensionOf(entry.url),
        cachedAt: now,
      );

  @override
  Future<List<Movie>> getVodStreams({String? categoryId}) async {
    final now = _clock();
    final result = <Movie>[];
    for (final entry in await _entriesOf(vod: true)) {
      final group = entry.groupTitle ?? _uncategorized;
      if (categoryId != null && group != categoryId) continue;
      result.add(_movieFrom(entry, group, now));
    }
    return result;
  }

  @override
  Future<Movie> getVodInfo(String vodId) async {
    // Scan for the single matching entry rather than building the whole VOD
    // list (150k Movie objects on a large playlist) just to pick one out.
    final now = _clock();
    for (final entry in (await _load()).entries) {
      if (!_isVod(entry) || stableId(entry.url) != vodId) continue;
      // No richer detail exists in an M3U — the list row IS the detail.
      return _movieFrom(entry, entry.groupTitle ?? _uncategorized, now);
    }
    throw SourceException('Unknown VOD item: $vodId');
  }

  @override
  Future<List<Category>> getSeriesCategories() async => const [];

  @override
  Future<List<Series>> getSeries({String? categoryId}) async => const [];

  @override
  Future<SeriesDetail> getSeriesInfo(String seriesId) async {
    throw const SourceException('M3U playlists do not provide series metadata');
  }

  @override
  Future<List<EpgEntry>> getShortEpg(String streamId, {int limit = 4}) async {
    // M3U has no per-channel EPG endpoint; now/next comes from the bulk XMLTV
    // at [xmltvUrl], ingested by the EPG repository.
    return const [];
  }

  @override
  String? get xmltvUrl => effectiveEpgUrl;

  @override
  Future<String> buildStreamUrl(StreamRef ref) async {
    // Resolve the id against the playlist, loading it if this is a fresh
    // instance (the app builds a new source per playback). Cached after the
    // first load for the life of this instance.
    final playlist = await _load();
    for (final entry in playlist.entries) {
      if (stableId(entry.url) == ref.streamId) return entry.url;
    }
    throw SourceException('Unknown stream: ${ref.streamId}');
  }
}
