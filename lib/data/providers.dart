import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/language/content_language.dart';
import '../domain/models/models.dart';
import 'db/app_database.dart';
import 'db/credential_store.dart';
import 'repositories/account_repository.dart';
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

final watchProgressRepositoryProvider = Provider<WatchProgressRepository>(
    (ref) => WatchProgressRepository(db: ref.watch(appDatabaseProvider)));

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
    (ref) => PreferencesRepository(db: ref.watch(appDatabaseProvider)));

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
    (ref) => FavoritesRepository(db: ref.watch(appDatabaseProvider)));

final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>(
    (ref) => SearchHistoryRepository(db: ref.watch(appDatabaseProvider)));

/// Recent search terms, newest first. Invalidate after recording/clearing.
final recentSearchesProvider = FutureProvider<List<String>>(
    (ref) => ref.watch(searchHistoryRepositoryProvider).recent());

/// All saved accounts. Invalidate after add/delete.
final accountsProvider = FutureProvider<List<Account>>(
    (ref) => ref.watch(accountRepositoryProvider).getAccounts());

/// The account the UI is showing. Invalidate after switching.
final activeAccountProvider = FutureProvider<Account?>(
    (ref) => ref.watch(accountRepositoryProvider).getActiveAccount());

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
  if (enabled == null) return null;
  final account = await ref.watch(activeAccountProvider.future);
  if (account == null) return null;
  final cats =
      await ref.watch(catalogRepositoryProvider).categories(account, type);
  return cats
      .where((c) => enabled.contains(detectContentLanguage(c.name).code))
      .map((c) => c.id)
      .toSet();
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
