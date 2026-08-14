import 'package:drift/drift.dart';

import '../../domain/models/account_identity.dart';
import 'app_database.dart';
import 'credential_store.dart';

/// Rewrites timestamp-derived account ids to the deterministic ones produced by
/// [stableAccountId], carrying every reference across with them.
///
/// This is a data migration, not a schema one, which is why it does not live in
/// drift's [MigrationStrategy]: it has to move the account's password in the
/// platform keychain, and secure storage is not reachable from inside a drift
/// migration. It runs once at startup instead, ahead of anything that reads an
/// account (see `accountIdMigrationProvider`).
///
/// Everything the old id appears in has to move together, or the user loses
/// something visible:
///
///  * the keychain entry — miss it and the account can no longer log in;
///  * the cached catalogue — miss it and the app silently re-downloads 200k+
///    items;
///  * `watch_progress` and `favorites` content keys — miss them and Continue
///    Watching and My List come back empty, which is the exact bug this whole
///    change exists to end.
class AccountIdMigration {
  AccountIdMigration({
    required this._db,
    required this._credentials,
  });

  final AppDatabase _db;
  final CredentialStore _credentials;

  /// Returns how many accounts were rewritten (0 on the common path, once the
  /// migration has already run or the install is new).
  Future<int> run() async {
    final rows = await _db.accountsTable.select().get();
    var migrated = 0;
    for (final row in rows) {
      final newId = stableAccountId(
        type: row.type,
        serverUrl: row.serverUrl,
        username: row.username,
      );
      if (newId == row.id) continue;

      // Copy the credential BEFORE touching the database, and delete the old
      // key only once everything else has landed. Crashing midway then leaves a
      // harmless orphan keychain entry; doing it the other way round would lose
      // the password outright.
      final password = await _credentials.readPassword(row.id);
      if (password != null) {
        await _credentials.savePassword(newId, password);
      }

      final isMerge = rows.any((other) => other.id == newId);
      await _rewrite(oldId: row.id, newId: newId, merge: isMerge);

      await _credentials.deletePassword(row.id);
      migrated++;
    }
    return migrated;
  }

  /// Repoints every row belonging to [oldId] at [newId], in one transaction.
  ///
  /// [merge] is set when a *different* account row already carries [newId] —
  /// which happens when the same playlist was added twice and the two entries
  /// now collapse onto one identity. In that case the duplicate account row is
  /// dropped rather than re-inserted, since its id is already taken.
  Future<void> _rewrite({
    required String oldId,
    required String newId,
    required bool merge,
  }) async {
    await _db.transaction(() async {
      // Column and table names come from drift's own getters, so a rename in
      // the schema cannot leave this SQL silently pointing at nothing.
      for (final (table, column) in <(TableInfo, GeneratedColumn)>[
        (_db.categoriesTable, _db.categoriesTable.accountId),
        (_db.moviesTable, _db.moviesTable.accountId),
        (_db.seriesTable, _db.seriesTable.accountId),
        (_db.episodesTable, _db.episodesTable.accountId),
        (_db.channelsTable, _db.channelsTable.accountId),
        (_db.epgCacheTable, _db.epgCacheTable.accountId),
        (_db.catalogMetaTable, _db.catalogMetaTable.accountId),
        (_db.catalogCategoryMetaTable,
            _db.catalogCategoryMetaTable.accountId),
        (_db.discoveryMatchesTable, _db.discoveryMatchesTable.accountId),
      ]) {
        // OR REPLACE because a merge can collide on the primary key: the same
        // catalogue row cached under both duplicate accounts. These tables are
        // caches, so either copy is equally valid.
        await _db.customStatement(
          'UPDATE OR REPLACE ${table.actualTableName} '
          'SET ${column.name} = ? WHERE ${column.name} = ?',
          [newId, oldId],
        );
      }

      // Content keys are `account:type:id`, so the account is a prefix ending
      // at the first colon. Matched with substr rather than LIKE deliberately:
      // every id contains an underscore, which LIKE treats as a
      // single-character wildcard, so `acc_123:%` would also match `accX123:`.
      for (final (table, column) in <(TableInfo, GeneratedColumn)>[
        (_db.watchProgressTable, _db.watchProgressTable.contentKey),
        (_db.favoritesTable, _db.favoritesTable.contentKey),
      ]) {
        await _db.customStatement(
          'UPDATE OR REPLACE ${table.actualTableName} '
          'SET ${column.name} = ? || substr(${column.name}, ?) '
          'WHERE substr(${column.name}, 1, ?) = ?',
          [newId, oldId.length + 1, oldId.length + 1, '$oldId:'],
        );
      }

      if (merge) {
        await (_db.accountsTable.delete()..where((t) => t.id.equals(oldId)))
            .go();
      } else {
        await _db.customStatement(
          'UPDATE ${_db.accountsTable.actualTableName} '
          'SET ${_db.accountsTable.id.name} = ? '
          'WHERE ${_db.accountsTable.id.name} = ?',
          [newId, oldId],
        );
      }

      // The active-account pointer is a plain id, not a content key.
      await (_db.preferencesTable.update()
            ..where((t) => t.activeAccountId.equals(oldId)))
          .write(PreferencesTableCompanion(activeAccountId: Value(newId)));
    });
  }
}
