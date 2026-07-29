import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// Recent search terms (PRD §8.6). Keeps the most-recent [_max]; re-searching
/// a term moves it back to the top rather than duplicating.
class SearchHistoryRepository {
  SearchHistoryRepository({required this._db, DateTime Function()? clock})
      : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _clock;

  static const int _max = 12;

  Future<void> record(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    await _db.searchHistoryTable.insertOnConflictUpdate(
      SearchHistoryTableCompanion.insert(
        query: q,
        searchedAtMillisUtc: _clock().millisecondsSinceEpoch,
      ),
    );
    final all = await (_db.searchHistoryTable.select()
          ..orderBy([(t) => OrderingTerm.desc(t.searchedAtMillisUtc)]))
        .get();
    if (all.length > _max) {
      final stale = all.skip(_max).map((r) => r.query).toList();
      await (_db.searchHistoryTable.delete()
            ..where((t) => t.query.isIn(stale)))
          .go();
    }
  }

  Future<List<String>> recent() async {
    final rows = await (_db.searchHistoryTable.select()
          ..orderBy([(t) => OrderingTerm.desc(t.searchedAtMillisUtc)])
          ..limit(_max))
        .get();
    return rows.map((r) => r.query).toList();
  }

  Future<void> remove(String query) async {
    await (_db.searchHistoryTable.delete()..where((t) => t.query.equals(query)))
        .go();
  }

  Future<void> clear() async {
    await _db.searchHistoryTable.delete().go();
  }
}
