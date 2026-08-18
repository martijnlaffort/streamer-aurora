import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../../domain/models/models.dart';
import 'json_values.dart';
import 'playlist_source.dart';

/// Xtream Codes client (PRD §6.1) against `player_api.php`.
///
/// Panels vary wildly; every row is parsed defensively — a malformed entry is
/// skipped and logged, never fatal. Only top-level failures (unreachable
/// panel, auth rejection, non-JSON body) throw [SourceException].
class XtreamSource implements PlaylistSource {
  XtreamSource({
    required this.account,
    Dio? dio,
    DateTime Function()? clock,
    void Function(String message)? onSkippedRow,
  })  : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 45),
        )),
        _clock = clock ?? (() => DateTime.now().toUtc()),
        _onSkippedRow = onSkippedRow ??
            ((m) => developer.log(m, name: 'XtreamSource'));

  final Account account;
  final Dio _dio;

  @override
  bool get supportsCategoryFetch => true;

  /// Injectable clock so tests get deterministic `cachedAt` values (UTC).
  final DateTime Function() _clock;
  final void Function(String message) _onSkippedRow;

  /// Server URL without a trailing slash.
  String get _server {
    final s = account.serverUrl.trim();
    return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  }

  Uri _api({String? action, Map<String, String> extra = const {}}) {
    return Uri.parse('$_server/player_api.php').replace(queryParameters: {
      'username': account.username,
      'password': account.password,
      'action': ?action,
      ...extra,
    });
  }

  /// GET + decode with the failure modes panels actually produce.
  Future<dynamic> _get({String? action, Map<String, String> extra = const {}}) async {
    final uri = _api(action: action, extra: extra);
    final Response<dynamic> response;
    try {
      response = await _dio.getUri<dynamic>(uri);
    } on DioException catch (e) {
      throw SourceException('Could not reach the panel: ${e.message}', e);
    }
    final data = response.data;
    if (data == null) {
      throw SourceException('Empty response from panel (${action ?? 'auth'})');
    }
    return data;
  }

  // --- Auth ------------------------------------------------------------------

  @override
  Future<void> authenticate() async {
    final data = optMap(await _get());
    final userInfo = optMap(data?['user_info']);
    if (userInfo == null) {
      throw const SourceException('Unexpected response — not an Xtream panel?');
    }
    final authed = optInt(userInfo['auth']) == 1;
    if (!authed) {
      throw const SourceException('Invalid username or password');
    }
    final status = optString(userInfo['status']);
    if (status != null && status.toLowerCase() != 'active') {
      throw SourceException('Account is not active (status: $status)');
    }
  }

  // --- Categories ------------------------------------------------------------

  Future<List<Category>> _categories(String action, CategoryType type) async {
    final rows = listOr(await _get(action: action));
    final result = <Category>[];
    for (final (index, row) in rows.indexed) {
      try {
        final map = optMap(row);
        if (map == null) throw const FormatException('row is not an object');
        final id = optString(map['category_id']);
        if (id == null) throw const FormatException('missing category_id');
        result.add(Category(
          id: id,
          accountId: account.id,
          type: type,
          name: stringOr(map['category_name'], 'Unnamed'),
          sortOrder: index,
        ));
      } catch (e) {
        _skip(action, index, e);
      }
    }
    return result;
  }

  @override
  Future<List<Category>> getLiveCategories() =>
      _categories('get_live_categories', CategoryType.live);

  @override
  Future<List<Category>> getVodCategories() =>
      _categories('get_vod_categories', CategoryType.vod);

  @override
  Future<List<Category>> getSeriesCategories() =>
      _categories('get_series_categories', CategoryType.series);

  // --- Live ------------------------------------------------------------------

  @override
  Future<List<Channel>> getLiveStreams({String? categoryId}) async {
    final rows = listOr(await _get(
      action: 'get_live_streams',
      extra: {'category_id': ?categoryId},
    ));
    final now = _clock();
    final result = <Channel>[];
    for (final (index, row) in rows.indexed) {
      try {
        final map = optMap(row);
        if (map == null) throw const FormatException('row is not an object');
        final id = optString(map['stream_id']);
        if (id == null) throw const FormatException('missing stream_id');
        result.add(Channel(
          id: id,
          accountId: account.id,
          categoryId: stringOr(map['category_id'], ''),
          name: stringOr(map['name'], 'Unnamed'),
          logoUrl: optString(map['stream_icon']),
          epgChannelId: optString(map['epg_channel_id']),
          sortOrder: optInt(map['num']),
          // Panels are inconsistent here: `tv_archive` arrives as 1, "1", or
          // true depending on the build, so treat anything truthy as yes.
          hasArchive: _truthy(map['tv_archive']),
          archiveDays: optInt(map['tv_archive_duration']),
          cachedAt: now,
        ));
      } catch (e) {
        _skip('get_live_streams', index, e);
      }
    }
    return result;
  }

  // --- VOD -------------------------------------------------------------------

  @override
  Future<List<Movie>> getVodStreams({String? categoryId}) async {
    final rows = listOr(await _get(
      action: 'get_vod_streams',
      extra: {'category_id': ?categoryId},
    ));
    final now = _clock();
    final result = <Movie>[];
    for (final (index, row) in rows.indexed) {
      try {
        final map = optMap(row);
        if (map == null) throw const FormatException('row is not an object');
        final id = optString(map['stream_id']);
        if (id == null) throw const FormatException('missing stream_id');
        result.add(Movie(
          id: id,
          accountId: account.id,
          categoryId: stringOr(map['category_id'], ''),
          name: stringOr(map['name'], 'Unnamed'),
          posterUrl: optString(map['stream_icon']),
          rating: optDouble(map['rating']),
          year: optYear(map['year'] ?? map['releasedate']),
          // Not every panel puts genre in the list response — most only give
          // it via get_vod_info — but reading it here costs nothing and is the
          // difference between the seasonal rails having something to work
          // with on a fresh catalogue and having nothing at all.
          genre: optString(map['genre']),
          containerExt: optString(map['container_extension']),
          addedAt: optUtcFromEpochSeconds(map['added']),
          cachedAt: now,
        ));
      } catch (e) {
        _skip('get_vod_streams', index, e);
      }
    }
    return result;
  }

  @override
  Future<Movie> getVodInfo(String vodId) async {
    final data = optMap(await _get(
      action: 'get_vod_info',
      extra: {'vod_id': vodId},
    ));
    final info = optMap(data?['info']) ?? const <String, dynamic>{};
    final movieData = optMap(data?['movie_data']) ?? const <String, dynamic>{};
    final id = optString(movieData['stream_id']) ?? vodId;
    return Movie(
      id: id,
      accountId: account.id,
      categoryId: stringOr(movieData['category_id'], ''),
      name: stringOr(info['name'] ?? movieData['name'], 'Unnamed'),
      posterUrl: optString(info['movie_image'] ?? info['cover_big']),
      backdropUrl: optFirstString(info['backdrop_path']),
      rating: optDouble(info['rating']),
      year: optYear(info['releasedate'] ?? info['year']),
      plot: optString(info['plot'] ?? info['description']),
      genre: optString(info['genre']),
      cast: optString(info['cast'] ?? info['actors']),
      durationSeconds: optInt(info['duration_secs']),
      containerExt: optString(movieData['container_extension']),
      addedAt: optUtcFromEpochSeconds(movieData['added']),
      cachedAt: _clock(),
    );
  }

  // --- Series ----------------------------------------------------------------

  @override
  Future<List<Series>> getSeries({String? categoryId}) async {
    final rows = listOr(await _get(
      action: 'get_series',
      extra: {'category_id': ?categoryId},
    ));
    final now = _clock();
    final result = <Series>[];
    for (final (index, row) in rows.indexed) {
      try {
        final map = optMap(row);
        if (map == null) throw const FormatException('row is not an object');
        final id = optString(map['series_id']);
        if (id == null) throw const FormatException('missing series_id');
        result.add(_seriesFromMap(map, id, now));
      } catch (e) {
        _skip('get_series', index, e);
      }
    }
    return result;
  }

  Series _seriesFromMap(Map<String, dynamic> map, String id, DateTime now) {
    return Series(
      id: id,
      accountId: account.id,
      categoryId: stringOr(map['category_id'], ''),
      name: stringOr(map['name'], 'Unnamed'),
      posterUrl: optString(map['cover']),
      backdropUrl: optFirstString(map['backdrop_path']),
      rating: optDouble(map['rating']),
      year: optYear(map['releaseDate'] ?? map['release_date']),
      plot: optString(map['plot']),
      genre: optString(map['genre']),
      cast: optString(map['cast']),
      cachedAt: now,
    );
  }

  @override
  Future<SeriesDetail> getSeriesInfo(String seriesId) async {
    final data = optMap(await _get(
      action: 'get_series_info',
      extra: {'series_id': seriesId},
    ));
    final now = _clock();
    final info = optMap(data?['info']) ?? const <String, dynamic>{};
    final series = _seriesFromMap(info, seriesId, now);

    // Episodes arrive as {"1": [..], "2": [..]} on most panels, but some send
    // a plain list of season-lists. Normalize both.
    final episodes = <Episode>[];
    final rawEpisodes = data?['episodes'];
    final seasonLists = <(String?, List<dynamic>)>[
      if (rawEpisodes is Map)
        for (final entry in rawEpisodes.entries)
          (optString(entry.key), listOr(entry.value)),
      if (rawEpisodes is List)
        for (final seasonList in rawEpisodes) (null, listOr(seasonList)),
    ];
    for (final (seasonKey, rows) in seasonLists) {
      for (final (index, row) in rows.indexed) {
        try {
          final map = optMap(row);
          if (map == null) throw const FormatException('row is not an object');
          final id = optString(map['id']);
          if (id == null) throw const FormatException('missing id');
          final epInfo = optMap(map['info']) ?? const <String, dynamic>{};
          final seasonNumber =
              optInt(map['season']) ?? optInt(seasonKey) ?? 0;
          episodes.add(Episode(
            id: id,
            seriesId: seriesId,
            seasonNumber: seasonNumber,
            episodeNumber: optInt(map['episode_num']) ?? index + 1,
            title: stringOr(map['title'], 'Episode ${index + 1}'),
            plot: optString(epInfo['plot']),
            durationSeconds: optInt(epInfo['duration_secs']),
            stillUrl: optString(epInfo['movie_image']),
            containerExt: optString(map['container_extension']),
            airDate: optUtcFromEpochSeconds(map['added']),
            cachedAt: now,
          ));
        } catch (e) {
          _skip('get_series_info/episodes', index, e);
        }
      }
    }
    episodes.sort((a, b) => a.seasonNumber != b.seasonNumber
        ? a.seasonNumber.compareTo(b.seasonNumber)
        : a.episodeNumber.compareTo(b.episodeNumber));

    // Seasons block is often incomplete or absent — derive missing ones from
    // the episodes themselves so the UI always has a season list.
    final seasons = <int, Season>{};
    for (final (index, row) in listOr(data?['seasons']).indexed) {
      try {
        final map = optMap(row);
        if (map == null) throw const FormatException('row is not an object');
        final number = optInt(map['season_number']);
        if (number == null) throw const FormatException('missing season_number');
        seasons[number] = Season(
          id: optString(map['id']) ?? '$seriesId-s$number',
          seriesId: seriesId,
          seasonNumber: number,
          name: optString(map['name']),
          posterUrl: optString(map['cover'] ?? map['cover_big']),
          episodeCount: optInt(map['episode_count']),
        );
      } catch (e) {
        _skip('get_series_info/seasons', index, e);
      }
    }
    for (final episode in episodes) {
      seasons.putIfAbsent(
        episode.seasonNumber,
        () => Season(
          id: '$seriesId-s${episode.seasonNumber}',
          seriesId: seriesId,
          seasonNumber: episode.seasonNumber,
        ),
      );
    }
    final seasonList = seasons.values.toList()
      ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));

    return SeriesDetail(series: series, seasons: seasonList, episodes: episodes);
  }

  // --- EPG -------------------------------------------------------------------

  @override
  Future<List<EpgEntry>> getShortEpg(String streamId, {int limit = 4}) async {
    final data = optMap(await _get(
      action: 'get_short_epg',
      extra: {'stream_id': streamId, 'limit': '$limit'},
    ));
    final result = <EpgEntry>[];
    for (final (index, row) in listOr(data?['epg_listings']).indexed) {
      try {
        final map = optMap(row);
        if (map == null) throw const FormatException('row is not an object');
        final start = optUtcFromEpochSeconds(map['start_timestamp']);
        final stop = optUtcFromEpochSeconds(map['stop_timestamp']);
        if (start == null || stop == null) {
          throw const FormatException('missing start/stop timestamps');
        }
        result.add(EpgEntry(
          channelId: optString(map['channel_id']) ?? streamId,
          start: start,
          stop: stop,
          title: optBase64Text(map['title']) ?? 'Unknown',
          description: optBase64Text(map['description']),
        ));
      } catch (e) {
        _skip('get_short_epg', index, e);
      }
    }
    return result;
  }

  @override
  String? get xmltvUrl {
    final u = Uri.encodeComponent(account.username);
    final p = Uri.encodeComponent(account.password);
    return '$_server/xmltv.php?username=$u&password=$p';
  }

  // --- Stream URLs (PRD §6.1) ------------------------------------------------

  /// Panels report booleans as 1, "1", or true depending on the build.
  static bool _truthy(Object? v) =>
      v == true || v == 1 || v == '1' || v == 'true';

  /// Xtream's timeshift path: the start time is panel-local wall clock in
  /// `Y-m-d:H-i`, and the duration is in minutes.
  static String _catchupStamp(DateTime start) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${start.year}-${two(start.month)}-${two(start.day)}:'
        '${two(start.hour)}-${two(start.minute)}';
  }

  @override
  Future<String> buildStreamUrl(StreamRef ref) async {
    final u = Uri.encodeComponent(account.username);
    final p = Uri.encodeComponent(account.password);
    // Catch-up replaces the live edge with a slice of the panel's recording.
    // The stamp is deliberately built from the LOCAL time: panels index their
    // archive by their own wall clock, and the EPG we matched the programme
    // against is already displayed in local time.
    if (ref.type == StreamType.live && ref.isCatchup) {
      final start = _catchupStamp(ref.catchupStart!.toLocal());
      return '$_server/timeshift/$u/$p/${ref.catchupMinutes}/$start/'
          '${ref.streamId}.${ref.containerExt ?? 'ts'}';
    }
    return switch (ref.type) {
      StreamType.live =>
        '$_server/live/$u/$p/${ref.streamId}.${ref.containerExt ?? 'ts'}',
      StreamType.movie =>
        '$_server/movie/$u/$p/${ref.streamId}.${ref.containerExt ?? 'mp4'}',
      StreamType.episode =>
        '$_server/series/$u/$p/${ref.streamId}.${ref.containerExt ?? 'mp4'}',
    };
  }

  void _skip(String action, int index, Object error) {
    _onSkippedRow('skipped $action[$index]: $error');
  }
}
