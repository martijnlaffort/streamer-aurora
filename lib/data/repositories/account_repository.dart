import 'package:drift/drift.dart';

import '../../domain/models/models.dart';
import '../db/app_database.dart';
import '../db/credential_store.dart';
import '../db/mappers.dart';

/// Accounts: metadata in drift, passwords ONLY in [CredentialStore].
class AccountRepository {
  AccountRepository({
    required this._db,
    required this._credentials,
  });

  final AppDatabase _db;
  final CredentialStore _credentials;

  /// Upserts the account row and stores the password in secure storage.
  Future<void> saveAccount(Account account) async {
    await _credentials.savePassword(account.id, account.password);
    await _db.accountsTable.insertOnConflictUpdate(account.toCompanion());
  }

  Future<List<Account>> getAccounts() async {
    final rows = await _db.accountsTable.select().get();
    return [
      for (final row in rows)
        row.toModel(password: await _credentials.readPassword(row.id) ?? ''),
    ];
  }

  Future<Account?> getAccount(String id) async {
    final row = await (_db.accountsTable.select()
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return row.toModel(password: await _credentials.readPassword(id) ?? '');
  }

  /// Removes the account, its credential, and every trace of its catalog,
  /// progress, and favorites.
  Future<void> deleteAccount(String id) async {
    await _credentials.deletePassword(id);
    await _db.transaction(() async {
      await (_db.accountsTable.delete()..where((t) => t.id.equals(id))).go();
      await (_db.categoriesTable.delete()
            ..where((t) => t.accountId.equals(id)))
          .go();
      await (_db.moviesTable.delete()..where((t) => t.accountId.equals(id))).go();
      await (_db.seriesTable.delete()..where((t) => t.accountId.equals(id))).go();
      await (_db.episodesTable.delete()..where((t) => t.accountId.equals(id))).go();
      await (_db.channelsTable.delete()..where((t) => t.accountId.equals(id))).go();
      await (_db.epgCacheTable.delete()..where((t) => t.accountId.equals(id))).go();
      await (_db.catalogMetaTable.delete()
            ..where((t) => t.accountId.equals(id)))
          .go();
      await (_db.watchProgressTable.delete()
            ..where((t) => t.contentKey.like('$id:%')))
          .go();
      await (_db.favoritesTable.delete()
            ..where((t) => t.contentKey.like('$id:%')))
          .go();
      // If it was the active account, clear the pointer.
      await (_db.preferencesTable.update()
            ..where((t) => t.activeAccountId.equals(id)))
          .write(const PreferencesTableCompanion(
              activeAccountId: Value(null)));
    });
  }

  static const _prefsId = 1;

  Future<void> setActiveAccount(String id) async {
    await _db.preferencesTable.insertOnConflictUpdate(
      PreferencesTableCompanion(
        id: const Value(_prefsId),
        activeAccountId: Value(id),
      ),
    );
  }

  Future<Account?> getActiveAccount() async {
    final prefs = await (_db.preferencesTable.select()
          ..where((t) => t.id.equals(_prefsId)))
        .getSingleOrNull();
    final id = prefs?.activeAccountId;
    if (id == null) return null;
    return getAccount(id);
  }
}
