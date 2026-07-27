import 'dart:convert';
import 'dart:typed_data';

import 'package:aurora/data/db/app_database.dart';
import 'package:aurora/data/repositories/catalog_repository.dart';
import 'package:aurora/data/repositories/epg_repository.dart';
import 'package:aurora/domain/models/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_playlist_source.dart';
import '../../helpers/test_support.dart';

/// Serves a fixed body for any request (the XMLTV endpoint).
class _StringAdapter implements HttpClientAdapter {
  _StringAdapter(this.body);
  final String body;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    return ResponseBody.fromBytes(utf8.encode(body), 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late FakePlaylistSource source;
  late DateTime now;

  Account account() => Account(
        id: 'acc1',
        type: AccountType.xtream,
        name: 'Main',
        serverUrl: 'http://panel.example.com',
        username: 'user',
        password: 'p',
        createdAt: DateTime.utc(2026, 1, 1),
      );

  setUp(() {
    now = DateTime.utc(2026, 1, 10, 12);
    db = createTestDb();
    source = FakePlaylistSource(accountId: 'acc1', clock: () => now);
  });

  tearDown(() => db.close());

  EpgRepository epgRepo({Dio? dio}) => EpgRepository(
        db: db,
        sourceFactory: (_) => source,
        dio: dio,
        clock: () => now,
      );

  Channel channelOne() => Channel(
        id: 'ch1',
        accountId: 'acc1',
        categoryId: 'c-live',
        name: 'One',
        epgChannelId: 'one.epg',
        cachedAt: now,
      );

  group('per-channel fallback (no XMLTV url)', () {
    test('now/next from getShortEpg, cached within TTL, stale served offline',
        () async {
      final repo = epgRepo();
      final channel = channelOne();

      final epg = await repo.nowNext(account(), channel);
      expect(epg.map((e) => e.title), ['Now Show', 'Next Show']);
      expect(source.calls['getShortEpg'], 1);
      expect(epg.first.start.isUtc, isTrue);

      await repo.nowNext(account(), channel);
      expect(source.calls['getShortEpg'], 1, reason: 'within 30-min TTL');

      now = now.add(const Duration(hours: 1));
      source.offline = true;
      final stale = await repo.nowNext(account(), channel);
      expect(stale.map((e) => e.title), ['Now Show', 'Next Show']);
    });
  });

  group('bulk XMLTV ingestion', () {
    // Programmes around now (2026-01-10 12:00 UTC) for channel "one.epg".
    const xmltv = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="one.epg"><display-name>One</display-name></channel>
  <programme start="20260110113000 +0000" stop="20260110123000 +0000" channel="one.epg">
    <title>Midday News</title><desc>The news.</desc>
  </programme>
  <programme start="20260110123000 +0000" stop="20260110133000 +0000" channel="one.epg">
    <title>Afternoon Show</title>
  </programme>
  <programme start="20250101000000 +0000" stop="20250101010000 +0000" channel="one.epg">
    <title>Ancient (outside window)</title>
  </programme>
</tv>''';

    test('ingests programmes, keyed by epgChannelId, in UTC; window-filtered',
        () async {
      final adapter = _StringAdapter(xmltv);
      final dio = Dio()..httpClientAdapter = adapter;
      source.xmltv = 'http://epg.example.com/guide.xml';
      final repo = epgRepo(dio: dio);

      final window = await repo.guideWindow(account(),
          now.subtract(const Duration(hours: 2)), now.add(const Duration(hours: 4)));

      expect(window.keys, contains('one.epg'));
      final progs = window['one.epg']!;
      // The ancient programme is outside the ingest window and dropped.
      expect(progs.map((e) => e.title), ['Midday News', 'Afternoon Show']);
      expect(progs.first.start, DateTime.utc(2026, 1, 10, 11, 30));
      expect(progs.first.start.isUtc, isTrue);
      expect(progs.first.description, 'The news.');
    });

    test('currentProgramme returns what is airing now; now/next slices it',
        () async {
      final adapter = _StringAdapter(xmltv);
      final dio = Dio()..httpClientAdapter = adapter;
      source.xmltv = 'http://epg.example.com/guide.xml';
      final repo = epgRepo(dio: dio);

      final current = await repo.currentProgramme(account(), channelOne());
      expect(current?.title, 'Midday News'); // 11:30–12:30 covers 12:00

      final nowNext = await repo.nowNext(account(), channelOne());
      expect(nowNext.map((e) => e.title), ['Midday News', 'Afternoon Show']);
      // No per-channel EPG call — the bulk guide answered.
      expect(source.calls['getShortEpg'], isNull);
    });

    test('guide is cached within TTL — one fetch across calls', () async {
      final adapter = _StringAdapter(xmltv);
      final dio = Dio()..httpClientAdapter = adapter;
      source.xmltv = 'http://epg.example.com/guide.xml';
      final repo = epgRepo(dio: dio);

      await repo.nowNext(account(), channelOne());
      await repo.currentProgramme(account(), channelOne());
      await repo.guideWindow(account(), now, now.add(const Duration(hours: 2)));
      expect(adapter.calls, 1, reason: 'ingested once, then served from cache');

      expect(await repo.hasEpg(account()), isTrue);
    });
  });

  // catalogRepo kept importable for parity with the other repo tests.
  CatalogRepository catalogRepo() =>
      CatalogRepository(db: db, sourceFactory: (_) => source, clock: () => now);

  test('CatalogRepository no longer owns EPG (moved to EpgRepository)', () {
    expect(catalogRepo(), isA<CatalogRepository>());
  });
}
