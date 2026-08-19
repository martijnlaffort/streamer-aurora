import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/mappers.dart';
import 'sync_backend.dart';

/// Favorites by content key (PRD §8.11), local-first with a sync seam.
///
/// A removal is a tombstone, not a delete: the row stays with `removed = true`
/// and a fresh `updatedAt`, so the removal propagates to other devices exactly
/// like an add (last-write-wins by `updatedAt`). My List only ever sees active
/// rows.
class FavoritesRepository {
  FavoritesRepository({
    required this._db,
    DateTime Function()? clock,
    this.onChanged,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Called after a local add/remove, so automatic sync can push it soon. Null
  /// in tests / when auto-sync is not wired. Deliberately not fired by
  /// [applyRemote], which is itself the result of a sync pull.
  final void Function()? onChanged;

  /// Returns the new state: true = now a favorite.
  Future<bool> toggle(String contentKey) async {
    final existing = await (_db.favoritesTable.select()
          ..where((t) => t.contentKey.equals(contentKey)))
        .getSingleOrNull();
    final wasActive = existing != null && !existing.removed;
    final nowActive = !wasActive;
    final now = utcMillis(_clock());
    await _db.favoritesTable.insertOne(
      FavoritesTableCompanion.insert(
        contentKey: contentKey,
        // Re-adding surfaces it as freshly added; a removal (else branch, where
        // `existing` is non-null) keeps the original add time.
        addedAtMillisUtc: nowActive ? now : existing.addedAtMillisUtc,
        removed: Value(!nowActive),
        updatedAtMillisUtc: Value(now),
      ),
      mode: InsertMode.insertOrReplace,
    );
    onChanged?.call();
    return nowActive;
  }

  Future<bool> isFavorite(String contentKey) async {
    final row = await (_db.favoritesTable.select()
          ..where((t) => t.contentKey.equals(contentKey) & t.removed.equals(false)))
        .getSingleOrNull();
    return row != null;
  }

  /// All active favorite content keys, newest first, with when they were added.
  Future<List<(String contentKey, DateTime addedAt)>> all() async {
    final rows = await (_db.favoritesTable.select()
          ..where((t) => t.removed.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.addedAtMillisUtc)]))
        .get();
    return [
      for (final r in rows) (r.contentKey, fromUtcMillis(r.addedAtMillisUtc)),
    ];
  }

  /// Every record, active and tombstoned, for a sync push.
  Future<List<FavoriteRecord>> allRecords() async {
    final rows = await _db.favoritesTable.select().get();
    return [
      for (final r in rows)
        (
          contentKey: r.contentKey,
          removed: r.removed,
          addedAt: fromUtcMillis(r.addedAtMillisUtc),
          updatedAt: fromUtcMillis(
              r.updatedAtMillisUtc == 0 ? r.addedAtMillisUtc : r.updatedAtMillisUtc),
        ),
    ];
  }

  /// Applies a record pulled from the backend, last-write-wins by [updatedAt]
  /// (PRD §9). A remote tombstone removes locally; a remote add restores.
  Future<void> applyRemote(FavoriteRecord record) async {
    final existing = await (_db.favoritesTable.select()
          ..where((t) => t.contentKey.equals(record.contentKey)))
        .getSingleOrNull();
    final localUpdated = existing == null
        ? -1
        : (existing.updatedAtMillisUtc == 0
            ? existing.addedAtMillisUtc
            : existing.updatedAtMillisUtc);
    if (utcMillis(record.updatedAt) <= localUpdated) return;
    await _db.favoritesTable.insertOne(
      FavoritesTableCompanion.insert(
        contentKey: record.contentKey,
        addedAtMillisUtc: utcMillis(record.addedAt),
        removed: Value(record.removed),
        updatedAtMillisUtc: Value(utcMillis(record.updatedAt)),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }
}
