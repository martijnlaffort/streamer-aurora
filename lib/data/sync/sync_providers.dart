import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'http_sync_backends.dart';
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
  return SyncService(
    progressRepo: ref.watch(watchProgressRepositoryProvider),
    preferencesRepo: ref.watch(preferencesRepositoryProvider),
    favoritesRepo: ref.watch(favoritesRepositoryProvider),
    progress: HttpProgressSyncBackend(baseUrl: baseUrl, token: token),
    preferences: HttpPreferencesSyncBackend(baseUrl: baseUrl, token: token),
    favorites: HttpFavoritesSyncBackend(baseUrl: baseUrl, token: token),
    configStore: ref.watch(syncConfigStoreProvider),
  );
});

/// Runs a reconcile if sync is configured. Returns null when sync is off.
/// Used on app open and by "Sync now". Refreshes data-layer providers whose
/// contents may have changed; UI callers invalidate their own view providers
/// (e.g. Home) afterwards.
Future<SyncResult?> runSync(WidgetRef ref) async {
  final service = await ref.read(syncServiceProvider.future);
  if (service == null) return null;
  final result = await service.reconcile();
  if (result.ok) {
    ref.invalidate(preferencesProvider);
    // A synced content key only shows in Continue Watching / My List once the
    // title it points at is in the local catalogue. History synced from
    // ANOTHER device references titles this one has never browsed, so pull
    // those in now — off Home's critical path, since sync runs after the first
    // frame. Home renders from cache immediately and is invalidated by the
    // caller once this returns. Best-effort; a title the panel dropped just
    // stays unresolved.
    final account = await ref.read(activeAccountProvider.future);
    if (account != null) {
      final catalog = ref.read(catalogRepositoryProvider);
      final progress =
          await ref.read(watchProgressRepositoryProvider).recentlyWatched();
      final favorites = await ref.read(favoritesRepositoryProvider).all();
      await catalog.ensureTitlesCached(account, [
        ...progress.map((p) => p.contentKey),
        ...favorites.map((f) => f.$1),
      ]);
    }
  }
  return result;
}
