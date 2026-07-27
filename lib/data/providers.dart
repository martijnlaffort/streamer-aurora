import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/models.dart';
import 'db/app_database.dart';
import 'db/credential_store.dart';
import 'repositories/account_repository.dart';
import 'repositories/catalog_repository.dart';
import 'repositories/epg_repository.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/preferences_repository.dart';
import 'repositories/watch_progress_repository.dart';
import 'sources/m3u_source.dart';
import 'sources/playlist_source.dart';
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

final watchProgressRepositoryProvider = Provider<WatchProgressRepository>(
    (ref) => WatchProgressRepository(db: ref.watch(appDatabaseProvider)));

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
    (ref) => PreferencesRepository(db: ref.watch(appDatabaseProvider)));

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
    (ref) => FavoritesRepository(db: ref.watch(appDatabaseProvider)));

/// All saved accounts. Invalidate after add/delete.
final accountsProvider = FutureProvider<List<Account>>(
    (ref) => ref.watch(accountRepositoryProvider).getAccounts());

/// The account the UI is showing. Invalidate after switching.
final activeAccountProvider = FutureProvider<Account?>(
    (ref) => ref.watch(accountRepositoryProvider).getActiveAccount());

/// Global playback preferences. Invalidate after saving.
final preferencesProvider = FutureProvider<Preferences>(
    (ref) => ref.watch(preferencesRepositoryProvider).get());
