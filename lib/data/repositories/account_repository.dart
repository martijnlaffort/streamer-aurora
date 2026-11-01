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
  ///
  /// Saving is an explicit add, so it also lifts an earlier deletion of the
  /// same playlist (the id is derived from server + login).
  Future<void> saveAccount(Account account) async {
    await _credentials.savePassword(account.id, account.password);
    await _credentials.clearDeleted(account.id);
    await _db.accountsTable.insertOnConflictUpdate(account.toCompanion());
  }

  /// Changes only the display name. The id stays, so progress, favourites and
  /// the cached catalogue keep belonging to it.
  Future<void> renameAccount(String id, String name) async {
    await (_db.accountsTable.update()..where((t) => t.id.equals(id)))
        .write(AccountsTableCompanion(name: Value(name)));
  }

  /// Whether this playlist was deleted on this device. Sync must not adopt it
  /// again: the server, and other devices, still hold it.
  Future<bool> wasDeleted(String id) => _credentials.isDeleted(id);

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
    // First, so a sync that lands mid-delete cannot re-adopt it.
    await _credentials.markDeleted(id);
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
      await (_db.catalogCategoryMetaTable.delete()
            ..where((t) => t.accountId.equals(id)))
          .go();
      // Was leaking: an account's resolved discovery rails outlived it, so a
      // deleted account's matches sat in the table forever.
      await (_db.discoveryMatchesTable.delete()
            ..where((t) => t.accountId.equals(id)))
          .go();
      // substr, not LIKE: every account id contains an underscore, and LIKE
      // reads `_` as a single-character wildcard, so `acc_123:%` would also
      // match a different account whose id merely lined up. An over-broad
      // pattern here deletes someone else's watch history.
      final keyPrefix = '$id:';
      await _db.customStatement(
        'DELETE FROM ${_db.watchProgressTable.actualTableName} '
        'WHERE substr(${_db.watchProgressTable.contentKey.name}, 1, ?) = ?',
        [keyPrefix.length, keyPrefix],
      );
      await _db.customStatement(
        'DELETE FROM ${_db.favoritesTable.actualTableName} '
        'WHERE substr(${_db.favoritesTable.contentKey.name}, 1, ?) = ?',
        [keyPrefix.length, keyPrefix],
      );
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
