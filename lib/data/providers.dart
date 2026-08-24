import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/language/content_language.dart';
import '../domain/models/models.dart';
import 'db/app_database.dart';
import 'db/credential_store.dart';
import 'repositories/account_repository.dart';
import 'repositories/artwork_repository.dart';
import 'repositories/catalog_overrides_repository.dart';
import 'repositories/catalog_repository.dart';
import 'repositories/discovery_repository.dart';
import 'repositories/epg_repository.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/preferences_repository.dart';
import 'repositories/search_history_repository.dart';
import 'repositories/watch_progress_repository.dart';
import 'sources/canon_source.dart';
import 'sources/m3u_source.dart';
import 'sources/playlist_source.dart';
import 'sources/tmdb_source.dart';
import 'sources/xtream_source.dart';
import 'db/account_id_migration.dart';
import 'sync/sync_trigger.dart';

/// Riverpod wiring for the data layer. The UI depends on these providers and
/// the domain models — never on sources or drift directly (PRD §5).

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final credentialStoreProvider =
    Provider<CredentialStore>((ref) => SecureCredentialStore());

/// Builds the right [PlaylistSource] for an account — the single place where
/// account type is dispatched.
final sourceFactoryProvider = Provider<PlaylistSource Function(Account)>((ref) {
  return (account) => switch (account.type) {
        AccountType.xtream => XtreamSource(account: account),
        AccountType.m3u => M3uSource(account: account, epgUrl: account.epgUrl),
      };
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    db: ref.watch(appDatabaseProvider),
    credentials: ref.watch(credentialStoreProvider),
  );
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(
    db: ref.watch(appDatabaseProvider),
    sourceFactory: ref.watch(sourceFactoryProvider),
  );
});

final epgRepositoryProvider = Provider<EpgRepository>((ref) {
  return EpgRepository(
    db: ref.watch(appDatabaseProvider),
    sourceFactory: ref.watch(sourceFactoryProvider),
  );
});

// --- Discovery (PRD §8.2 "Popular") -----------------------------------------

final canonSourceProvider = Provider<CanonSource>((ref) => CanonSource());

/// The region used for "popular/new *here*" — the user's explicit choice, else
/// the device locale's country, else NL.
String _resolveRegion(String? configured) {
  if (configured != null && configured.length == 2) return configured;
  final locale = PlatformDispatcher.instance.locale;
  final country = locale.countryCode;
  if (country != null && country.length == 2) return country.toUpperCase();
  return 'NL';
}

/// The resolved discovery region, exposed so the UI can name it ("Top 10 in NL").
final discoveryRegionProvider = Provider<String>((ref) =>
    _resolveRegion(ref.watch(preferencesProvider).value?.discoveryRegion));

final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) {
  // Watched, not read: saving a key in Settings must rebuild this so the TMDB
  // rails light up without a restart.
  final prefs = ref.watch(preferencesProvider).value;
  return DiscoveryRepository(
    db: ref.watch(appDatabaseProvider),
    canon: ref.watch(canonSourceProvider),
    tmdbFactory: () {
      final key = prefs?.tmdbApiKey;
      if (key == null || key.isEmpty) return null;
      return TmdbSource(
          apiKey: key, region: _resolveRegion(prefs?.discoveryRegion));
    },
  );
});

/// Artwork for titles the panel has no image for. Shares the TMDB key with the
/// discovery rails; with no key configured it simply never finds anything.
final artworkRepositoryProvider = Provider<ArtworkRepository>((ref) {
  final prefs = ref.watch(preferencesProvider).value;
  return ArtworkRepository(
    ref.watch(appDatabaseProvider),
    () {
      final key = prefs?.tmdbApiKey;
      if (key == null || key.isEmpty) return null;
      return TmdbSource(
          apiKey: key, region: _resolveRegion(prefs?.discoveryRegion));
    },
  );
});

/// Poster for a title the panel gave us none for, or null. Resolved lazily by
/// the card that needs it, so nothing is fetched for titles never scrolled to.
final artworkProvider = FutureProvider.autoDispose
    .family<String?, ArtworkQuery>((ref, query) async {
  // Keep a resolved poster around briefly so scrolling a rail back and forth
  // does not re-read for every rebuild.
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  return ref.watch(artworkRepositoryProvider).posterFor(
        name: query.name,
        year: query.year,
        isSeries: query.isSeries,
      );
});

/// Identity of an artwork lookup — value equality so the family caches.
class ArtworkQuery {
  const ArtworkQuery(
      {required this.name, required this.isSeries, this.year});

  final String name;
  final int? year;
  final bool isSeries;

  @override
  bool operator ==(Object other) =>
      other is ArtworkQuery &&
      other.name == name &&
      other.year == year &&
      other.isSeries == isSeries;

  @override
  int get hashCode => Object.hash(name, year, isSeries);
}

final watchProgressRepositoryProvider = Provider<WatchProgressRepository>(
    (ref) => WatchProgressRepository(
          db: ref.watch(appDatabaseProvider),
          onChanged: () => ref.read(syncTriggerProvider).ping(),
        ));

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
    (ref) => PreferencesRepository(db: ref.watch(appDatabaseProvider)));

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
    (ref) => FavoritesRepository(
          db: ref.watch(appDatabaseProvider),
          onChanged: () => ref.read(syncTriggerProvider).ping(),
        ));

/// The user's size multiplier. Text scales through MediaQuery in [DawnPlayerApp];
/// posters and rails are laid out in logical pixels, so they read this instead.
final uiScaleProvider = Provider<double>(
    (ref) => ref.watch(preferencesProvider).value?.uiScale ?? 1.0);

final catalogOverridesRepositoryProvider =
    Provider<CatalogOverridesRepository>((ref) =>
        CatalogOverridesRepository(db: ref.watch(appDatabaseProvider)));

/// The active account's hidden / renamed / reordered categories and channels.
final catalogOverridesProvider = FutureProvider<CatalogOverrides>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return CatalogOverrides.empty;
  return ref.watch(catalogOverridesRepositoryProvider).forAccount(account.id);
});

/// Categories for one slice as the user wants to see them: the content-language
/// filter applied, then their own hiding, renaming and ordering.
///
/// Shared by the Live, Movies and Series tabs so the three cannot drift apart.
Future<List<Category>> visibleCategories(Ref ref, CategoryType type) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const [];
  final all = await ref.watch(catalogRepositoryProvider).categories(account, type);
  final enabled = await ref.watch(contentLanguageFilterProvider.future);
  final byLanguage = enabled == null
      ? all
      : [
          for (final c in all)
            if (enabled.contains(detectContentLanguage(c.name).code)) c,
        ];
  final overrides = await ref.watch(catalogOverridesProvider.future);
  if (overrides.isEmpty) return byLanguage;
  final visible =
      overrides.applyToCategories(byLanguage, idOf: (Category c) => c.id);
  return [
    for (final c in visible)
      Category(
        id: c.id,
        accountId: c.accountId,
        type: c.type,
        name: overrides.categoryName(c.id, c.name),
        sortOrder: c.sortOrder,
      ),
  ];
}

final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
    (ref) => SearchHistoryRepository(db: ref.watch(appDatabaseProvider)));

/// Recent search terms, newest first. Invalidate after recording/clearing.
final recentSearchesProvider = FutureProvider<List<String>>(
    (ref) => ref.watch(searchHistoryRepositoryProvider).recent());

/// Runs the timestamp-id → stable-id rewrite exactly once per launch.
///
/// Every account read goes through this first. That ordering is the whole
/// point: if anything resolved an account before the rewrite, it would cache
/// the old id and then write content keys under a prefix that is about to stop
/// existing.
final accountIdMigrationProvider = FutureProvider<int>((ref) async {
  return AccountIdMigration(
    db: ref.watch(appDatabaseProvider),
    credentials: ref.watch(credentialStoreProvider),
  ).run();
});

/// All saved accounts. Invalidate after add/delete.
final accountsProvider = FutureProvider<List<Account>>((ref) async {
  await ref.watch(accountIdMigrationProvider.future);
  return ref.watch(accountRepositoryProvider).getAccounts();
});

/// The account the UI is showing. Invalidate after switching.
final activeAccountProvider = FutureProvider<Account?>((ref) async {
  await ref.watch(accountIdMigrationProvider.future);
  return ref.watch(accountRepositoryProvider).getActiveAccount();
});

/// Global playback preferences. Invalidate after saving.
final preferencesProvider = FutureProvider<Preferences>(
    (ref) => ref.watch(preferencesRepositoryProvider).get());

// --- Content-language filter (PRD §8.3) ------------------------------------

/// The set of [ContentLanguage] codes to show, or `null` when the filter is
/// off (unconfigured, or every language enabled) → show everything.
final contentLanguageFilterProvider = FutureProvider<Set<String>?>((ref) async {
  final prefs = await ref.watch(preferencesProvider.future);
  final codes = prefs.contentLanguages;
  if (codes == null || codes.isEmpty) return null;
  return codes.toSet();
});

/// Category IDs of [type] whose detected language is enabled, or `null` when
/// the filter is off (→ no restriction). Drives filtering of the unscoped
/// title lists (Home rails, the "All" grids).
final allowedCategoryIdsProvider =
    FutureProvider.family<Set<String>?, CategoryType>((ref, type) async {
  final enabled = await ref.watch(contentLanguageFilterProvider.future);
  final overrides = await ref.watch(catalogOverridesProvider.future);
  // Null means "no restriction", which is only true when neither the language
  // filter nor a hidden category is narrowing things.
  if (enabled == null && overrides.hiddenCategories.isEmpty) return null;
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return null;
  final cats =
      await ref.watch(catalogRepositoryProvider).categories(account, type);
  return {
    for (final c in cats)
      if (!overrides.hiddenCategories.contains(c.id) &&
          (enabled == null ||
              enabled.contains(detectContentLanguage(c.name).code)))
        c.id,
  };
});

/// Languages present across the active account's categories, with how many
/// categories fall in each — powers the Settings picker. Sorted by size, with
/// "Other" pinned last.
final availableContentLanguagesProvider =
    FutureProvider<List<({ContentLanguage lang, int count})>>((ref) async {
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return const [];
  final catalog = ref.watch(catalogRepositoryProvider);
  final counts = <String, int>{};
  final labels = <String, String>{};
  for (final type in CategoryType.values) {
    for (final category in await catalog.categories(account, type)) {
      final lang = detectContentLanguage(category.name);
      counts[lang.code] = (counts[lang.code] ?? 0) + 1;
      labels[lang.code] = lang.label;
    }
  }
  final result = [
    for (final entry in counts.entries)
      (lang: ContentLanguage(entry.key, labels[entry.key]!), count: entry.value)
  ];
  result.sort((a, b) {
    if (a.lang.code == ContentLanguage.other.code) return 1;
    if (b.lang.code == ContentLanguage.other.code) return -1;
    return b.count.compareTo(a.count);
  });
  return result;
});
