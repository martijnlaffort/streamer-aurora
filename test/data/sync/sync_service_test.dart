import 'package:dawnplayer/data/db/app_database.dart';
import 'package:dawnplayer/data/repositories/favorites_repository.dart';
import 'package:dawnplayer/data/repositories/preferences_repository.dart';
import 'package:dawnplayer/data/repositories/sync_backend.dart';
import 'package:dawnplayer/data/repositories/watch_progress_repository.dart';
import 'package:dawnplayer/data/sync/sync_config.dart' show SyncStateStore;
import 'package:dawnplayer/data/sync/sync_service.dart';
import 'package:dawnplayer/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_support.dart';

class _FakeProgress implements ProgressSyncBackend {
  List<WatchProgress> remote = [];
  final pushed = <WatchProgress>[];
  @override
  Future<void> push(List<WatchProgress> e) async => pushed.addAll(e);
  @override
  Future<List<WatchProgress>> pullSince(DateTime? since) async => remote;
}

class _FakePrefs implements PreferencesSyncBackend {
  (Preferences, DateTime)? pushed;
  ({Preferences prefs, DateTime updatedAt})? winner;
  @override
  Future<void> push(Preferences p, DateTime at) async => pushed = (p, at);
  @override
  Future<({Preferences prefs, DateTime updatedAt})?> pull() async => winner;
}

class _FakeFavs implements FavoritesSyncBackend {
  List<String> remote = [];
  final pushed = <String>[];
  @override
  Future<void> push(List<String> keys) async => pushed.addAll(keys);
  @override
  Future<List<String>> pull() async => remote;
}

class _MemState implements SyncStateStore {
  DateTime? last;
  DateTime? prefs;
  @override
  Future<DateTime?> lastSyncAt() async => last;
  @override
  Future<void> setLastSyncAt(DateTime at) async => last = at;
  @override
  Future<DateTime?> preferencesChangedAt() async => prefs;
  @override
  Future<void> setPreferencesChangedAt(DateTime at) async => prefs = at;
}

void main() {
  late AppDatabase db;
  late DateTime now;
  late WatchProgressRepository progressRepo;
  late PreferencesRepository prefsRepo;
  late FavoritesRepository favRepo;
  late _FakeProgress progress;
  late _FakePrefs prefs;
  late _FakeFavs favs;
  late _MemState state;

  setUp(() {
    now = DateTime.utc(2026, 2, 1, 12);
    db = createTestDb();
    progressRepo = WatchProgressRepository(db: db, clock: () => now);
    prefsRepo = PreferencesRepository(db: db);
    favRepo = FavoritesRepository(db: db, clock: () => now);
    progress = _FakeProgress();
    prefs = _FakePrefs();
    favs = _FakeFavs();
    state = _MemState();
  });

  tearDown(() => db.close());

  SyncService service() => SyncService(
        progressRepo: progressRepo,
        preferencesRepo: prefsRepo,
        favoritesRepo: favRepo,
        progress: progress,
        preferences: prefs,
        favorites: favs,
        configStore: state,
        clock: () => now,
      );

  WatchProgress remoteProgress(String key, int pos, DateTime at) => WatchProgress(
        contentKey: key,
        positionSeconds: pos,
        durationSeconds: 1000,
        updatedAt: at,
        completed: false,
      );

  test('progress last-write-wins: newer remote applied, older ignored, dirty '
      'pushed', () async {
    // Local A edited now (12:00), still dirty.
    await progressRepo.savePosition(
        contentKey: 'acc:movie:A', positionSeconds: 100, durationSeconds: 1000);

    progress.remote = [
      remoteProgress('acc:movie:A', 50, DateTime.utc(2026, 2, 1, 11)), // older
      remoteProgress('acc:movie:B', 200, DateTime.utc(2026, 2, 1, 13)), // newer
    ];

    final result = await service().reconcile();
    expect(result.ok, isTrue);

    // A keeps the newer local value; B is applied from remote.
    expect((await progressRepo.get('acc:movie:A'))!.positionSeconds, 100);
    expect((await progressRepo.get('acc:movie:B'))!.positionSeconds, 200);

    // Only the locally-dirty A is pushed; the freshly-applied B is not.
    expect(progress.pushed.map((e) => e.contentKey), ['acc:movie:A']);
    expect(result.pulledProgress, 1);
    expect(result.pushedProgress, 1);
    expect(state.last, now); // watermark advanced
  });

  test('preferences: local pushed with its changed-at; server winner applied',
      () async {
    await prefsRepo.save(const Preferences(preferredAudioLang: 'eng'));
    await state.setPreferencesChangedAt(DateTime.utc(2026, 2, 1, 10));
    prefs.winner = (
      prefs: const Preferences(preferredAudioLang: 'nld'),
      updatedAt: DateTime.utc(2026, 2, 1, 14),
    );

    await service().reconcile();

    // Pushed the local prefs with the local changed-at.
    expect(prefs.pushed!.$1.preferredAudioLang, 'eng');
    expect(prefs.pushed!.$2, DateTime.utc(2026, 2, 1, 10));
    // The server's winner is applied and its timestamp recorded.
    expect((await prefsRepo.get()).preferredAudioLang, 'nld');
    expect(state.prefs, DateTime.utc(2026, 2, 1, 14));
  });

  test('favorites union: remote-only added locally, local-only pushed',
      () async {
    await favRepo.toggle('acc:movie:X'); // local only
    favs.remote = ['acc:movie:Y']; // remote only

    await service().reconcile();

    final local = (await favRepo.all()).map((e) => e.$1).toSet();
    expect(local, containsAll(['acc:movie:X', 'acc:movie:Y']));
    expect(favs.pushed, ['acc:movie:X']);
  });

  test('reconcile surfaces a backend error instead of throwing', () async {
    final failing = SyncService(
      progressRepo: progressRepo,
      preferencesRepo: prefsRepo,
      favoritesRepo: favRepo,
      progress: _ThrowingProgress(),
      preferences: prefs,
      favorites: favs,
      configStore: state,
      clock: () => now,
    );
    final result = await failing.reconcile();
    expect(result.ok, isFalse);
    expect(result.error, isNotNull);
  });
}

class _ThrowingProgress implements ProgressSyncBackend {
  @override
  Future<void> push(List<WatchProgress> e) async => throw Exception('boom');
  @override
  Future<List<WatchProgress>> pullSince(DateTime? since) async =>
      throw Exception('boom');
}
