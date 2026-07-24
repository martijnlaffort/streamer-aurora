import 'package:aurora/data/db/app_database.dart';
import 'package:aurora/data/db/mappers.dart';
import 'package:aurora/data/repositories/account_repository.dart';
import 'package:aurora/data/repositories/catalog_repository.dart';
import 'package:aurora/data/repositories/favorites_repository.dart';
import 'package:aurora/data/repositories/preferences_repository.dart';
import 'package:aurora/data/repositories/watch_progress_repository.dart';
import 'package:aurora/data/sources/playlist_source.dart';
import 'package:aurora/domain/models/models.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_playlist_source.dart';
import '../../helpers/test_support.dart';

void main() {
  late AppDatabase db;
  late InMemoryCredentialStore credentials;
  late FakePlaylistSource source;
  late DateTime now;

  Account account() => Account(
        id: 'acc1',
        type: AccountType.xtream,
        name: 'Main',
        serverUrl: 'http://panel.example.com',
        username: 'user',
        password: 'secret-password',
        createdAt: DateTime.utc(2026, 1, 1),
      );

  setUp(() {
    now = DateTime.utc(2026, 1, 10, 12);
    db = createTestDb();
    credentials = InMemoryCredentialStore();
    source = FakePlaylistSource(accountId: 'acc1', clock: () => now);
  });

  tearDown(() => db.close());

  CatalogRepository catalogRepo() => CatalogRepository(
        db: db,
        sourceFactory: (_) => source,
        clock: () => now,
      );

  group('AccountRepository (DoD: credentials live in secure storage)', () {
    test('password is stored in the credential store, never in the DB', () async {
      final repo = AccountRepository(db: db, credentials: credentials);
      await repo.saveAccount(account(), epgUrl: 'http://epg.example.com/x.xml');

      final rawRow = await db.accountsTable.select().getSingle();
      expect(credentials.passwords['acc1'], 'secret-password');
      // The row type has no password field at all; sanity-check the stored
      // column values don't leak it either.
      expect(rawRow.toString().contains('secret-password'), isFalse);
      expect(rawRow.username, 'user');
      expect(rawRow.epgUrl, 'http://epg.example.com/x.xml');
      expect(rawRow.createdAtMillisUtc,
          DateTime.utc(2026, 1, 1).millisecondsSinceEpoch);
    });

    test('read back reconstructs the full account incl. password', () async {
      final repo = AccountRepository(db: db, credentials: credentials);
      await repo.saveAccount(account());

      final loaded = await repo.getAccount('acc1');
      expect(loaded, account());
      expect(loaded!.createdAt.isUtc, isTrue);
    });

    test('active account switching persists; delete cleans everything',
        () async {
      final repo = AccountRepository(db: db, credentials: credentials);
      await repo.saveAccount(account());
      await repo.setActiveAccount('acc1');
      expect((await repo.getActiveAccount())!.id, 'acc1');

      // Populate catalog + progress + favorites, then delete the account.
      await catalogRepo().movies(account());
      await WatchProgressRepository(db: db, clock: () => now).savePosition(
          contentKey: 'acc1:movie:1001',
          positionSeconds: 100,
          durationSeconds: 1000);
      await FavoritesRepository(db: db, clock: () => now)
          .toggle('acc1:movie:1001');

      await repo.deleteAccount('acc1');
      expect(await repo.getAccount('acc1'), isNull);
      expect(await repo.getActiveAccount(), isNull);
      expect(credentials.passwords, isEmpty);
      expect(await db.moviesTable.select().get(), isEmpty);
      expect(await db.watchProgressTable.select().get(), isEmpty);
      expect(await db.favoritesTable.select().get(), isEmpty);
    });
  });

  group('CatalogRepository (DoD: cache catalog, read back offline)', () {
    test('first read fetches and caches; second read hits only the cache',
        () async {
      final repo = catalogRepo();
      final first = await repo.movies(account());
      expect(first.map((m) => m.name), ['Alpha Movie', 'Beta Movie']);
      expect(source.calls['getVodStreams'], 1);

      final second = await repo.movies(account());
      expect(second, hasLength(2));
      expect(source.calls['getVodStreams'], 1, reason: 'fresh TTL — no refetch');
    });

    test('cached catalog is readable with the network off', () async {
      await catalogRepo().movies(account());
      await catalogRepo().channels(account());

      source.offline = true;
      final repo = catalogRepo();
      expect(await repo.movies(account()), hasLength(2));
      expect(await repo.channels(account()), hasLength(3));
      expect((await repo.categories(account(), CategoryType.vod)).single.name,
          'Movies');
    });

    test('never-fetched + offline propagates the source error', () async {
      source.offline = true;
      expect(() => catalogRepo().movies(account()),
          throwsA(isA<SourceException>()));
    });

    test('stale TTL serves cache immediately and refreshes in background',
        () async {
      final repo = catalogRepo();
      await repo.movies(account());
      expect(source.calls['getVodStreams'], 1);

      now = now.add(const Duration(hours: 13)); // beyond the 12h TTL
      source.vodStreams = [
        Movie(
            id: '2001',
            accountId: 'acc1',
            categoryId: 'c-vod',
            name: 'Fresh Movie',
            cachedAt: now),
      ];
      final served = await repo.movies(account());
      expect(served.map((m) => m.name), ['Alpha Movie', 'Beta Movie'],
          reason: 'stale cache served immediately');
      await repo.lastBackgroundRefresh;
      expect(source.calls['getVodStreams'], 2);
      expect((await repo.movies(account())).map((m) => m.name),
          ['Fresh Movie']);
    });

    test('stale TTL + offline: cache still the answer, no throw', () async {
      final repo = catalogRepo();
      await repo.movies(account());
      now = now.add(const Duration(hours: 13));
      source.offline = true;

      final served = await repo.movies(account());
      expect(served, hasLength(2));
      await repo.lastBackgroundRefresh; // failure swallowed + logged
    });

    test('paged reads', () async {
      final repo = catalogRepo();
      await repo.movies(account());
      final page = await repo.movies(account(), limit: 1, offset: 1);
      expect(page.single.name, 'Beta Movie');
    });

    test('all cached timestamps are UTC millis (DoD)', () async {
      final repo = catalogRepo();
      await repo.movies(account());
      final raw = await db.moviesTable.select().get();
      for (final row in raw) {
        expect(row.cachedAtMillisUtc, utcMillis(now));
      }
      final models = await repo.movies(account());
      for (final m in models) {
        expect(m.cachedAt.isUtc, isTrue);
      }
    });

    test('movieDetail enriches the cached row and works offline afterwards',
        () async {
      final repo = catalogRepo();
      await repo.movies(account());
      final detail = await repo.movieDetail(account(), '1001');
      expect(detail.plot, 'Enriched plot from the panel.');

      source.offline = true;
      final offlineDetail = await repo.movieDetail(account(), '1001');
      expect(offlineDetail.plot, 'Enriched plot from the panel.');
      expect(offlineDetail.genre, 'Drama');
    });

    test('seriesDetail caches episodes and rebuilds offline with derived '
        'seasons', () async {
      final repo = catalogRepo();
      await repo.series(account());
      final detail = await repo.seriesDetail(account(), 's15');
      expect(detail.episodes, hasLength(3));

      source.offline = true;
      final offline = await repo.seriesDetail(account(), 's15');
      expect(offline.series.name, 'Fake Show');
      expect(offline.episodes.map((e) => e.id), ['e1', 'e2', 'e3']);
      expect(offline.seasons.map((s) => s.seasonNumber), [1, 2]);
    });

    test('EPG: cached within TTL, stale cache served offline', () async {
      final repo = catalogRepo();
      await repo.channels(account());
      final channel = (await repo.channels(account())).first;

      final epg = await repo.shortEpg(account(), channel);
      expect(epg, hasLength(2));
      expect(source.calls['getShortEpg'], 1);

      await repo.shortEpg(account(), channel);
      expect(source.calls['getShortEpg'], 1, reason: 'within EPG TTL');

      now = now.add(const Duration(hours: 1)); // beyond 30 min TTL
      source.offline = true;
      final stale = await repo.shortEpg(account(), channel);
      expect(stale.map((e) => e.title), ['Now Show', 'Next Show']);
      expect(stale.first.start.isUtc, isTrue);
    });
  });

  group('WatchProgressRepository', () {
    test('save/read with UTC updatedAt; §8.9 windows; completion rule',
        () async {
      final repo = WatchProgressRepository(db: db, clock: () => now);
      final saved = await repo.savePosition(
          contentKey: 'acc1:movie:1001',
          positionSeconds: 500,
          durationSeconds: 1000);
      expect(saved.updatedAt, now);
      expect(saved.completed, isFalse);
      expect(repo.shouldOfferResume(saved), isTrue);

      final early = await repo.savePosition(
          contentKey: 'acc1:movie:x', positionSeconds: 20, durationSeconds: 1000);
      expect(repo.shouldOfferResume(early), isFalse, reason: 'under 5%');

      final done = await repo.savePosition(
          contentKey: 'acc1:movie:y', positionSeconds: 960, durationSeconds: 1000);
      expect(done.completed, isTrue, reason: 'past 95% auto-completes');

      final row = await (db.watchProgressTable.select()
            ..where((t) => t.contentKey.equals('acc1:movie:1001')))
          .getSingle();
      expect(row.updatedAtMillisUtc, utcMillis(now));
    });

    test('continue watching: unfinished only, most recent first', () async {
      final repo = WatchProgressRepository(db: db, clock: () => now);
      await repo.savePosition(
          contentKey: 'acc1:movie:a', positionSeconds: 100, durationSeconds: 1000);
      now = now.add(const Duration(minutes: 5));
      await repo.savePosition(
          contentKey: 'acc1:episode:b', positionSeconds: 300, durationSeconds: 1000);
      now = now.add(const Duration(minutes: 5));
      await repo.savePosition(
          contentKey: 'acc1:movie:done', positionSeconds: 990, durationSeconds: 1000);

      final rail = await repo.continueWatching();
      expect(rail.map((p) => p.contentKey), ['acc1:episode:b', 'acc1:movie:a']);

      await repo.markCompleted('acc1:episode:b');
      expect((await repo.continueWatching()).map((p) => p.contentKey),
          ['acc1:movie:a']);
    });

    test('unsynced entries expose the sync seam', () async {
      final repo = WatchProgressRepository(db: db, clock: () => now);
      await repo.savePosition(
          contentKey: 'acc1:movie:a', positionSeconds: 1, durationSeconds: 100);
      expect((await repo.unsyncedEntries()).single.syncedAt, isNull);
    });
  });

  group('PreferencesRepository', () {
    test('defaults, then persisted roundtrip', () async {
      final repo = PreferencesRepository(db: db);
      expect(await repo.get(), const Preferences.defaults());

      const prefs = Preferences(
          preferredAudioLang: 'eng',
          preferredSubtitleLang: 'nl',
          autoplayNext: false);
      await repo.save(prefs);
      expect(await repo.get(), prefs);
    });
  });

  group('FavoritesRepository', () {
    test('toggle on/off, newest-first listing with UTC addedAt', () async {
      final repo = FavoritesRepository(db: db, clock: () => now);
      final key1 = contentKeyFor(
          accountId: 'acc1', type: StreamType.movie, id: '1001');
      expect(key1, 'acc1:movie:1001');

      expect(await repo.toggle(key1), isTrue);
      now = now.add(const Duration(minutes: 1));
      expect(await repo.toggle('acc1:live:ch1'), isTrue);
      expect(await repo.isFavorite(key1), isTrue);

      final all = await repo.all();
      expect(all.map((f) => f.$1), ['acc1:live:ch1', key1]);
      expect(all.first.$2.isUtc, isTrue);

      expect(await repo.toggle(key1), isFalse);
      expect(await repo.isFavorite(key1), isFalse);
    });
  });
}
