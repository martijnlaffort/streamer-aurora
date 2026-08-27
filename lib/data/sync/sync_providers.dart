import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import '../providers.dart';
import 'http_sync_backends.dart';
import 'playback_activity.dart';
import 'sync_config.dart';
import 'sync_service.dart';

final syncConfigStoreProvider =
    Provider<SyncConfigStore>((ref) => SyncConfigStore());

/// Current sync config. Invalidate after saving.
final syncConfigProvider = FutureProvider<SyncConfig>(
    (ref) => ref.watch(syncConfigStoreProvider).read());

/// A [SyncService] wired to the configured backend, or null when sync is off
/// or unconfigured.
final syncServiceProvider = FutureProvider<SyncService?>((ref) async {
  final config = await ref.watch(syncConfigProvider.future);
  if (!config.isConfigured) return null;

  final baseUrl = config.baseUrl!;
  final token = config.token!;
  final catalog = ref.watch(catalogRepositoryProvider);
  return SyncService(
    progressRepo: ref.watch(watchProgressRepositoryProvider),
    preferencesRepo: ref.watch(preferencesRepositoryProvider),
    favoritesRepo: ref.watch(favoritesRepositoryProvider),
    progress: HttpProgressSyncBackend(baseUrl: baseUrl, token: token),
    preferences: HttpPreferencesSyncBackend(baseUrl: baseUrl, token: token),
    favorites: HttpFavoritesSyncBackend(baseUrl: baseUrl, token: token),
    accountsRepo: ref.watch(accountRepositoryProvider),
    accounts: HttpAccountSyncBackend(baseUrl: baseUrl, token: token),
    overridesRepo: ref.watch(catalogOverridesRepositoryProvider),
    overrides: HttpOverridesSyncBackend(baseUrl: baseUrl, token: token),
    configStore: ref.watch(syncConfigStoreProvider),
    // Tag outgoing episode progress with its series id, resolved from the
    // local catalogue (the episode is cached here — it was watched here).
    resolveSeriesId: (episodeId) async {
      final account = await ref.read(activeAccountProvider.future);
      if (account == null) return null;
      final episode = await catalog.episodeById(account, episodeId);
      return episode?.seriesId;
    },
  );
});

/// Runs a reconcile if sync is configured. Returns null when sync is off.
/// The single entry point for every automatic trigger (launch, resume,
/// background, debounced-on-change, periodic — see the app-level coordinator).
/// Refreshes data-layer providers whose contents may have changed; UI callers
/// invalidate their own view providers (e.g. Home) afterwards.
Future<SyncResult?> runSync(WidgetRef ref) async {
  final service = await ref.read(syncServiceProvider.future);
  if (service == null) return null;
  var result = await service.reconcile();
  if (result.ok) {
    // Invalidate ONLY what the reconcile actually changed. These providers are
    // dependencies of Home, My List, the Live list and the category filters, so
    // invalidating them on every 2-minute cycle sent all of those into
    // `isReloading` — and `AsyncValue.when` shows its loading branch on a
    // reload, which is exactly the "screen refreshes itself" the user saw.
    if (result.preferencesChanged) ref.invalidate(preferencesProvider);
    if (result.accountsChanged) {
      // A playlist synced in from another device is a new account row; refresh
      // the account providers so it shows up (and so the read below sees any
      // active account the reconcile just adopted on a fresh device).
      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);
    }
    // A synced content key only shows in Continue Watching / My List once the
    // title it points at is in the local catalogue. History synced from
    // ANOTHER device references titles this one has never browsed, so pull
    // those in now — off Home's critical path, since sync runs after the first
    // frame. Home renders from cache immediately and is invalidated by the
    // caller once this returns. Best-effort; a title the panel dropped just
    // stays unresolved.
    final account = await ref.read(activeAccountProvider.future);
    // Never behind a playing video. The reconcile above is a few small requests,
    // but this backfill can be dozens of full series/movie detail fetches, and a
    // long-running series is a big response — enough to compete with the stream
    // on the same connection and surface as buffering. It is pure catch-up, so
    // deferring it to the next sync after playback costs nothing.
    final playing = ref.read(playbackActivityProvider).isPlaying;
    if (account != null && !playing) {
      final catalog = ref.read(catalogRepositoryProvider);
      final progressRepo = ref.read(watchProgressRepositoryProvider);
      final progress = await progressRepo.recentlyWatched();
      final favorites = await ref.read(favoritesRepositoryProvider).all();
      // Series behind episode progress — the piece that lets a part-watched
      // series reappear in Continue Watching on this device.
      //
      // Taken from the STORED rows, not just from what this pull returned, so a
      // series that failed to fetch (offline, timeout, or past the per-run cap)
      // is retried next sync instead of being lost the moment the watermark
      // moved on. Two properties matter and are easy to get wrong:
      //  * BOUNDED — `progress` is `recentlyWatched()`, already capped, so this
      //    can never grow into an unbounded per-cycle fetch list.
      //  * ORDERED BY RECENCY — a LinkedHashSet preserving that order, because
      //    the backfill takes only the first N. Feeding it an unordered set
      //    starves everything past N forever; ordered, the N it fetches are the
      //    N the rail can actually show.
      // Scoped to the active account: a series id belonging to another playlist
      // would be fetched against the wrong panel, and a miss there would count
      // against the id for the account it IS valid on.
      final orderedSeriesIds = <String>{
        for (final p in progress)
          if (parseContentKey(p.contentKey)?.accountId == account.id)
            ?p.seriesId,
        ...result.pulledSeriesIds,
      };
      final backfilled = await catalog.ensureTitlesCached(
        account,
        [
          ...progress.map((p) => p.contentKey),
          ...favorites.map((f) => f.$1),
        ],
        extraSeriesIds: orderedSeriesIds,
      );
      // Caching a title is itself a reason to rebuild the rails: the common
      // convergence case is a sync that pulled nothing new but finally resolved
      // a series, and without this the card stays invisible until something
      // unrelated changes.
      if (backfilled) result = result.withBackfill();
    }
  }
  return result;
}
