import '../../domain/models/models.dart';
import '../repositories/account_repository.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/preferences_repository.dart';
import '../repositories/sync_backend.dart';
import '../repositories/watch_progress_repository.dart';
import 'sync_config.dart' show SyncStateStore;

class SyncResult {
  const SyncResult({
    this.pulledProgress = 0,
    this.pushedProgress = 0,
    this.pulledSeriesIds = const {},
    this.accountsChanged = false,
    this.preferencesChanged = false,
    this.favoritesChanged = false,
    this.backfilledTitles = false,
    this.error,
  });

  /// Same result, but noting that the catalogue backfill cached something.
  SyncResult withBackfill() => SyncResult(
        pulledProgress: pulledProgress,
        pushedProgress: pushedProgress,
        pulledSeriesIds: pulledSeriesIds,
        accountsChanged: accountsChanged,
        preferencesChanged: preferencesChanged,
        favoritesChanged: favoritesChanged,
        backfilledTitles: true,
        error: error,
      );

  final int pulledProgress;
  final int pushedProgress;

  /// Whether the reconcile actually altered local state. The automatic sync
  /// runs every couple of minutes, and invalidating providers it did not change
  /// is what made the screen visibly "refresh itself" on a TV: providers that
  /// Home *depends on* going stale send Home's own AsyncValue into
  /// `isReloading`, and `AsyncValue.when` shows its `loading` branch on a
  /// reload by default (`skipLoadingOnReload` is false). So: only invalidate
  /// what really moved.
  final bool accountsChanged;
  final bool preferencesChanged;
  final bool favoritesChanged;

  /// The catalogue backfill cached a title the rails were waiting on. Set by
  /// the caller (see runSync), not by the reconcile itself — and it MUST count
  /// as a change, because the usual convergence step is a sync that pulls
  /// nothing new and simply resolves a series that failed to fetch earlier.
  final bool backfilledTitles;

  /// Anything at all changed locally — the cue for the UI to rebuild its rails.
  bool get changedLocally =>
      pulledProgress > 0 ||
      accountsChanged ||
      preferencesChanged ||
      favoritesChanged ||
      backfilledTitles;

  /// Series ids referenced by episode progress just pulled from the backend.
  /// The caller backfills these — the series has to be fetched and cached
  /// before an episode key from another device can resolve into Continue
  /// Watching.
  final Set<String> pulledSeriesIds;
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
/// - **Favorites**: per-record last-write-wins with tombstones — a removal is a
///   dated tombstone that propagates like an add, so removing something from My
///   List on one device removes it everywhere.
/// - **Accounts**: union by the account's stable id, so a playlist added on any
///   device appears on the others (with its credentials). Deletions are not
///   synced. Skipped entirely when no account repo/backend is wired.
class SyncService {
  SyncService({
    required this._progressRepo,
    required this._preferencesRepo,
    required this._favoritesRepo,
    required this._progress,
    required this._preferences,
    required this._favorites,
    required this._configStore,
    this._resolveSeriesId,
    this._accountsRepo,
    this._accounts,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final WatchProgressRepository _progressRepo;
  final PreferencesRepository _preferencesRepo;
  final FavoritesRepository _favoritesRepo;
  final ProgressSyncBackend _progress;
  final PreferencesSyncBackend _preferences;
  final FavoritesSyncBackend _favorites;
  final SyncStateStore _configStore;
  final AccountRepository? _accountsRepo;
  final AccountSyncBackend? _accounts;

  /// Looks up which series an episode belongs to, from the local catalogue.
  /// Used to tag outgoing episode progress so the other device can resolve it.
  /// Null in tests / when no catalogue is wired.
  final Future<String?> Function(String episodeId)? _resolveSeriesId;
  final DateTime Function() _clock;

  Future<SyncResult> reconcile() async {
    try {
      // Accounts first: pulling a new playlist makes its content keys
      // resolvable, so progress/favorites for it can land somewhere real.
      final accountsChanged = await _reconcileAccounts();
      // Stamp the watermark from BEFORE the pull, not after the whole reconcile.
      // A record another device writes to the server during this reconcile
      // window has a timestamp later than the pull but earlier than "now"; using
      // "now" as the next `since` would skip it forever. Using the pull-start
      // time re-pulls that window next time — idempotent under last-write-wins.
      final syncStartedAt = _clock();
      final (:pulled, :seriesIds) = await _reconcileProgress();
      final pushed = await _pushDirtyProgress();
      final preferencesChanged = await _reconcilePreferences();
      final favoritesChanged = await _reconcileFavorites();
      await _configStore.setLastSyncAt(syncStartedAt);
      return SyncResult(
          pulledProgress: pulled,
          pushedProgress: pushed,
          pulledSeriesIds: seriesIds,
          accountsChanged: accountsChanged,
          preferencesChanged: preferencesChanged,
          favoritesChanged: favoritesChanged);
    } on Object catch (e) {
      return SyncResult(error: '$e');
    }
  }

  Future<({int pulled, Set<String> seriesIds})> _reconcileProgress() async {
    final since = await _configStore.lastSyncAt();
    final remote = await _progress.pullSince(since);
    var applied = 0;
    final seriesIds = <String>{};
    for (final r in remote) {
      if (r.seriesId != null) seriesIds.add(r.seriesId!);
      final local = await _progressRepo.get(r.contentKey);
      if (local == null || r.updatedAt.isAfter(local.updatedAt)) {
        await _progressRepo.applyRemote(r);
        applied++;
      }
    }
    return (pulled: applied, seriesIds: seriesIds);
  }

  Future<int> _pushDirtyProgress() async {
    final unsynced = await _progressRepo.unsyncedEntries();
    if (unsynced.isEmpty) return 0;
    // Tag episode entries with their series id so the receiving device can
    // fetch the series and resolve the episode. The episode is cached here (it
    // was watched here), so the lookup is local and cheap.
    final enriched = <WatchProgress>[];
    for (final e in unsynced) {
      final key = parseContentKey(e.contentKey);
      if (e.seriesId != null ||
          _resolveSeriesId == null ||
          key == null ||
          key.type != StreamType.episode.name) {
        enriched.add(e); // already tagged, or nothing to tag
        continue;
      }
      final seriesId = await _resolveSeriesId(key.id);
      enriched.add(seriesId == null ? e : e.copyWith(seriesId: seriesId));
    }
    await _progress.push(enriched);
    // Pass the ENRICHED entries, not just the keys: markSynced clears the dirty
    // flag only on rows still at the pushed `updatedAt` (a save that landed
    // during the push above bumped it and stays dirty, so its newer position is
    // pushed next time instead of being silently swallowed) — and it persists
    // any series id resolved above, so this device also stops relying on a
    // one-shot lookup.
    await _progressRepo.markSynced(enriched);
    return unsynced.length;
  }

  /// Returns whether local preferences were actually changed by the server.
  Future<bool> _reconcilePreferences() async {
    final local = await _preferencesRepo.get();
    final changedAt = await _configStore.preferencesChangedAt() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    await _preferences.push(local, changedAt);
    final winner = await _preferences.pull();
    if (winner != null) {
      // Nothing to apply when the server agrees with us — and applying it
      // anyway would invalidate the preferences provider on every cycle, which
      // reloads everything that depends on it.
      final same = winner.prefs.preferredAudioLang == local.preferredAudioLang &&
          winner.prefs.preferredSubtitleLang == local.preferredSubtitleLang &&
          winner.prefs.autoplayNext == local.autoplayNext &&
          winner.prefs.backgroundPlayback == local.backgroundPlayback;
      if (same) return false;
      // The TMDB key, discovery region and content-language filter are all
      // device-local and NOT part of the sync payload, so carry the local
      // values across — saving the remote winner verbatim would clear them on
      // every sync. (contentLanguages was previously missed here, so the
      // language filter silently reset to "show all" after each sync.)
      await _preferencesRepo.save(winner.prefs.copyWith(
        tmdbApiKey: local.tmdbApiKey,
        discoveryRegion: local.discoveryRegion,
        contentLanguages: local.contentLanguages,
      ));
      await _configStore.setPreferencesChangedAt(winner.updatedAt);
      return true;
    }
    return false;
  }

  /// Returns whether any favourite was actually added, removed or restored here.
  Future<bool> _reconcileFavorites() async {
    // Pull remote records and apply the ones newer than local (LWW, tombstones
    // included), then push the full local set — the backend arbitrates LWW, so
    // re-pushing already-current rows is a harmless no-op.
    var changed = false;
    for (final r in await _favorites.pull()) {
      // applyRemote owns the last-write-wins test and reports whether it wrote.
      if (await _favoritesRepo.applyRemote(r)) changed = true;
    }
    await _favorites.push(await _favoritesRepo.allRecords());
    return changed;
  }

  /// Returns whether a playlist was adopted or the active account was set.
  Future<bool> _reconcileAccounts() async {
    final repo = _accountsRepo;
    final backend = _accounts;
    if (repo == null || backend == null) return false;
    var changed = false;

    // Union: adopt any remote playlist we don't already have, credentials and
    // all. LWW on renames is deliberately not attempted — the account id is
    // derived from the server + login, so the identity never drifts.
    final remote = await backend.pull();
    final localIds = (await repo.getAccounts()).map((a) => a.id).toSet();
    for (final r in remote) {
      if (localIds.contains(r.accountId)) continue;
      await repo.saveAccount(Account(
        id: r.accountId,
        type: AccountType.values.firstWhere((t) => t.name == r.type,
            orElse: () => AccountType.xtream),
        name: r.name,
        serverUrl: r.serverUrl,
        username: r.username,
        password: r.password,
        createdAt: r.updatedAt,
        epgUrl: r.epgUrl,
      ));
      changed = true;
    }

    final local = await repo.getAccounts();
    // A freshly-synced device has no active account yet — adopt one so Home has
    // something to show without making the user pick.
    if (local.isNotEmpty && await repo.getActiveAccount() == null) {
      await repo.setActiveAccount(local.first.id);
      changed = true;
    }

    await backend.push([
      for (final a in local)
        (
          accountId: a.id,
          type: a.type.name,
          name: a.name,
          serverUrl: a.serverUrl,
          username: a.username,
          password: a.password,
          epgUrl: a.epgUrl,
          updatedAt: a.createdAt,
        ),
    ]);
    return changed;
  }
}
