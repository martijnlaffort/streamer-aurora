import '../repositories/favorites_repository.dart';
import '../repositories/preferences_repository.dart';
import '../repositories/sync_backend.dart';
import '../repositories/watch_progress_repository.dart';
import 'sync_config.dart' show SyncStateStore;

class SyncResult {
  const SyncResult({
    this.pulledProgress = 0,
    this.pushedProgress = 0,
    this.error,
  });

  final int pulledProgress;
  final int pushedProgress;
  final String? error;

  bool get ok => error == null;
}

/// Reconciles local repositories with the sync backends (PRD §9). Local is the
/// source of truth; conflicts resolve last-write-wins by UTC `updatedAt`.
///
/// - **Progress**: proper per-record LWW — pull changes since the last sync,
///   apply the ones newer than local, then push everything still dirty.
/// - **Preferences**: pushed with the local "changed at" timestamp; the server
///   arbitrates LWW and the winner is applied back.
/// - **Favorites**: union merge (adds propagate both ways). Removals do *not*
///   propagate — there are no tombstones; a favorite removed on one device
///   stays on the others until removed there too.
class SyncService {
  SyncService({
    required this._progressRepo,
    required this._preferencesRepo,
    required this._favoritesRepo,
    required this._progress,
    required this._preferences,
    required this._favorites,
    required this._configStore,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final WatchProgressRepository _progressRepo;
  final PreferencesRepository _preferencesRepo;
  final FavoritesRepository _favoritesRepo;
  final ProgressSyncBackend _progress;
  final PreferencesSyncBackend _preferences;
  final FavoritesSyncBackend _favorites;
  final SyncStateStore _configStore;
  final DateTime Function() _clock;

  Future<SyncResult> reconcile() async {
    try {
      final pulled = await _reconcileProgress();
      final pushed = await _pushDirtyProgress();
      await _reconcilePreferences();
      await _reconcileFavorites();
      await _configStore.setLastSyncAt(_clock());
      return SyncResult(pulledProgress: pulled, pushedProgress: pushed);
    } on Object catch (e) {
      return SyncResult(error: '$e');
    }
  }

  Future<int> _reconcileProgress() async {
    final since = await _configStore.lastSyncAt();
    final remote = await _progress.pullSince(since);
    var applied = 0;
    for (final r in remote) {
      final local = await _progressRepo.get(r.contentKey);
      if (local == null || r.updatedAt.isAfter(local.updatedAt)) {
        await _progressRepo.applyRemote(r);
        applied++;
      }
    }
    return applied;
  }

  Future<int> _pushDirtyProgress() async {
    final unsynced = await _progressRepo.unsyncedEntries();
    if (unsynced.isEmpty) return 0;
    await _progress.push(unsynced);
    await _progressRepo.markSynced(unsynced.map((e) => e.contentKey));
    return unsynced.length;
  }

  Future<void> _reconcilePreferences() async {
    final local = await _preferencesRepo.get();
    final changedAt = await _configStore.preferencesChangedAt() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    await _preferences.push(local, changedAt);
    final winner = await _preferences.pull();
    if (winner != null) {
      // The TMDB key and discovery region are device-local and are not part of
      // the sync payload, so carry the local values across — saving the remote
      // winner verbatim would clear them on every sync.
      await _preferencesRepo.save(winner.prefs.copyWith(
        tmdbApiKey: local.tmdbApiKey,
        discoveryRegion: local.discoveryRegion,
      ));
      await _configStore.setPreferencesChangedAt(winner.updatedAt);
    }
  }

  Future<void> _reconcileFavorites() async {
    final remote = (await _favorites.pull()).toSet();
    final local = (await _favoritesRepo.all()).map((e) => e.$1).toSet();
    for (final key in remote.difference(local)) {
      await _favoritesRepo.addIfAbsent(key, _clock());
    }
    final localOnly = local.difference(remote).toList();
    if (localOnly.isNotEmpty) await _favorites.push(localOnly);
  }
}
