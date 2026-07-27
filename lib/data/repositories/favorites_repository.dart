import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../db/mappers.dart';
import 'sync_backend.dart';

/// Favorites by content key (PRD §8.11), local-first with a sync seam.
class FavoritesRepository {
  FavoritesRepository({
    required this._db,
    DateTime Function()? clock,
    // Accepted but unused until the Phase 2 backend exists.
    // ignore: avoid_unused_constructor_parameters
    FavoritesSyncBackend? backend,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Returns the new state: true = now a favorite.
  Future<bool> toggle(String contentKey) async {
    final existing = await (_db.favoritesTable.select()
          ..where((t) => t.contentKey.equals(contentKey)))
        .getSingleOrNull();
    if (existing != null) {
      await (_db.favoritesTable.delete()
            ..where((t) => t.contentKey.equals(contentKey)))
          .go();
      return false;
    }
    await _db.favoritesTable.insertOne(FavoritesTableCompanion.insert(
      contentKey: contentKey,
      addedAtMillisUtc: utcMillis(_clock()),
    ));
    return true;
  }

  Future<bool> isFavorite(String contentKey) async {
    final row = await (_db.favoritesTable.select()
          ..where((t) => t.contentKey.equals(contentKey)))
        .getSingleOrNull();
    return row != null;
  }

  /// All favorite content keys, newest first, with when they were added (UTC).
  Future<List<(String contentKey, DateTime addedAt)>> all() async {
    final rows = await (_db.favoritesTable.select()
          ..orderBy([(t) => OrderingTerm.desc(t.addedAtMillisUtc)]))
        .get();
    return [
      for (final r in rows) (r.contentKey, fromUtcMillis(r.addedAtMillisUtc)),
    ];
  }

  /// Adds a favorite from a sync pull if not already present (union merge —
  /// PRD §9). Removals don't propagate (no tombstones); documented in
  /// SyncService.
  Future<void> addIfAbsent(String contentKey, DateTime addedAt) async {
    await _db.favoritesTable.insertOne(
      FavoritesTableCompanion.insert(
        contentKey: contentKey,
        addedAtMillisUtc: utcMillis(addedAt),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }
}
