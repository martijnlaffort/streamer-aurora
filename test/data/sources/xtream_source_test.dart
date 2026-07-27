import 'dart:io';
import 'dart:typed_data';

import 'package:aurora/data/sources/playlist_source.dart';
import 'package:aurora/data/sources/xtream_source.dart';
import 'package:aurora/domain/models/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves saved fixture responses keyed by the `action` query parameter
/// (no action → the auth response). Replaces Dio's real HTTP layer.
class _FixtureAdapter implements HttpClientAdapter {
  _FixtureAdapter(this.byAction);

  /// action (or '' for auth) → fixture file name.
  final Map<String, String> byAction;
  final List<Uri> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    final action = options.uri.queryParameters['action'] ?? '';
    final file = byAction[action];
    if (file == null) {
      return ResponseBody.fromString('not found', 404);
    }
    return ResponseBody.fromString(
      File('test/fixtures/xtream/$file').readAsStringSync(),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final fixedNow = DateTime.utc(2026, 1, 1, 12);
  final account = Account(
    id: 'acc1',
    type: AccountType.xtream,
    name: 'Test',
    serverUrl: 'http://panel.example.com:8080/',
    username: 'u1',
    password: 'p 1+&', // exercises URL encoding in stream URLs
    createdAt: DateTime.utc(2026, 1, 1),
  );

  (XtreamSource, _FixtureAdapter, List<String>) build(
      Map<String, String> byAction) {
    final adapter = _FixtureAdapter(byAction);
    final dio = Dio()..httpClientAdapter = adapter;
    final skipped = <String>[];
    final source = XtreamSource(
      account: account,
      dio: dio,
      clock: () => fixedNow,
      onSkippedRow: skipped.add,
    );
    return (source, adapter, skipped);
  }

  group('authenticate', () {
    test('succeeds for an active account', () async {
      final (source, adapter, _) = build({'': 'auth_ok.json'});
      await source.authenticate();
      expect(adapter.requests.single.path, '/player_api.php');
      expect(adapter.requests.single.queryParameters['username'], 'u1');
    });

    test('throws a displayable error on bad credentials', () async {
      final (source, _, _) = build({'': 'auth_bad.json'});
      expect(
        () => source.authenticate(),
        throwsA(isA<SourceException>().having(
            (e) => e.message, 'message', contains('Invalid username'))),
      );
    });

    test('throws when the account is not active', () async {
      final (source, _, _) = build({'': 'auth_expired.json'});
      expect(
        () => source.authenticate(),
        throwsA(isA<SourceException>()
            .having((e) => e.message, 'message', contains('Expired'))),
      );
    });
  });

  group('categories', () {
    test('maps rows, skips malformed ones, preserves order', () async {
      final (source, _, skipped) =
          build({'get_live_categories': 'get_live_categories.json'});
      final categories = await source.getLiveCategories();

      expect(categories, hasLength(3));
      expect(categories[0].id, '4');
      expect(categories[0].name, 'NL | ALGEMEEN');
      expect(categories[0].type, CategoryType.live);
      expect(categories[0].sortOrder, 0);
      // Numeric id coerced to string; empty name falls back.
      expect(categories[1].id, '7');
      expect(categories[2].name, 'Unnamed');
      // Missing-id row and non-object row were skipped, not fatal.
      expect(skipped, hasLength(2));
    });
  });

  group('live streams', () {
    test('maps channels with mixed id types and skips junk', () async {
      final (source, _, skipped) =
          build({'get_live_streams': 'get_live_streams.json'});
      final channels = await source.getLiveStreams();

      expect(channels, hasLength(2));
      expect(channels[0].id, '242');
      expect(channels[0].name, 'NPO 1 HD');
      expect(channels[0].epgChannelId, 'npo1.nl');
      expect(channels[0].sortOrder, 1);
      expect(channels[0].cachedAt, fixedNow);
      expect(channels[1].id, '243');
      expect(channels[1].logoUrl, isNull); // "" → null
      expect(channels[1].epgChannelId, isNull);
      expect(skipped, hasLength(2));
    });

    test('passes category_id filter through', () async {
      final (source, adapter, _) =
          build({'get_live_streams': 'get_live_streams.json'});
      await source.getLiveStreams(categoryId: '4');
      expect(adapter.requests.single.queryParameters['category_id'], '4');
    });
  });

  group('vod', () {
    test('maps movies with string/number ratings and epoch added', () async {
      final (source, _, skipped) =
          build({'get_vod_streams': 'get_vod_streams.json'});
      final movies = await source.getVodStreams();

      expect(movies, hasLength(2));
      expect(movies[0].id, '1001');
      expect(movies[0].rating, 7.2);
      expect(movies[0].containerExt, 'mkv');
      expect(movies[0].addedAt,
          DateTime.fromMillisecondsSinceEpoch(1690000000 * 1000, isUtc: true));
      expect(movies[0].addedAt!.isUtc, isTrue);
      expect(movies[1].rating, 6.0);
      expect(movies[1].year, 2023);
      expect(skipped, hasLength(1));
    });

    test('vod info merges info + movie_data, handles backdrop list', () async {
      final (source, _, _) = build({'get_vod_info': 'get_vod_info.json'});
      final movie = await source.getVodInfo('1001');

      expect(movie.id, '1001');
      expect(movie.name, 'Some Movie');
      expect(movie.plot, 'A longer plot line.');
      expect(movie.genre, 'Action / Drama');
      expect(movie.cast, 'Actor A, Actor B, Actor C');
      expect(movie.backdropUrl, 'http://cdn.example.com/movie1-backdrop.jpg');
      expect(movie.durationSeconds, 7260);
      expect(movie.year, 2024);
      expect(movie.containerExt, 'mkv');
    });
  });

  group('series', () {
    test('maps series list and skips junk', () async {
      final (source, _, skipped) = build({'get_series': 'get_series.json'});
      final series = await source.getSeries();

      expect(series, hasLength(2));
      expect(series[0].id, '15');
      expect(series[0].genre, 'Drama');
      expect(series[0].year, 2020);
      expect(series[0].backdropUrl, 'http://cdn.example.com/show15-bd.jpg');
      expect(series[1].id, '16');
      expect(skipped, hasLength(1));
    });

    test('series info: episodes sorted, seasons derived when missing',
        () async {
      final (source, _, skipped) =
          build({'get_series_info': 'get_series_info.json'});
      final detail = await source.getSeriesInfo('15');

      expect(detail.series.name, 'Great Show');
      expect(detail.episodes, hasLength(3));
      expect(detail.episodes.map((e) => e.id), ['5001', '5002', '5010']);
      // Season taken from the episodes-map key when the row omits it.
      expect(detail.episodes[2].seasonNumber, 2);
      expect(detail.episodes[2].durationSeconds, 2600); // "2600" string
      // Season 1 from the seasons block, season 2 derived from episodes.
      expect(detail.seasons.map((s) => s.seasonNumber), [1, 2]);
      expect(detail.seasons[0].name, 'Season 1');
      expect(detail.episodesOfSeason(1), hasLength(2));
      // One malformed season row + one malformed episode row skipped.
      expect(skipped, hasLength(2));
    });
  });

  group('epg', () {
    test('decodes base64 titles, keeps plain text, skips entries without '
        'timestamps', () async {
      final (source, _, skipped) =
          build({'get_short_epg': 'get_short_epg.json'});
      final epg = await source.getShortEpg('242');

      expect(epg, hasLength(2));
      expect(epg[0].title, 'News');
      expect(epg[0].description, 'Evening news');
      expect(epg[0].start,
          DateTime.fromMillisecondsSinceEpoch(1753380000 * 1000, isUtc: true));
      expect(epg[0].start.isUtc, isTrue);
      expect(epg[1].title, 'Plain text title');
      expect(skipped, hasLength(1));
    });
  });

  group('stream URLs (PRD §6.1)', () {
    test('builds live/movie/episode URLs with encoding and defaults',
        () async {
      final (source, _, _) = build({});

      expect(
        await source.buildStreamUrl(const StreamRef(
            accountId: 'acc1', type: StreamType.live, streamId: '242')),
        'http://panel.example.com:8080/live/u1/p%201%2B%26/242.ts',
      );
      expect(
        await source.buildStreamUrl(const StreamRef(
            accountId: 'acc1',
            type: StreamType.movie,
            streamId: '1001',
            containerExt: 'mkv')),
        'http://panel.example.com:8080/movie/u1/p%201%2B%26/1001.mkv',
      );
      expect(
        await source.buildStreamUrl(const StreamRef(
            accountId: 'acc1', type: StreamType.episode, streamId: '5001')),
        'http://panel.example.com:8080/series/u1/p%201%2B%26/5001.mp4',
      );
    });
  });
}
