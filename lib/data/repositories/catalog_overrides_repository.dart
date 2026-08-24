import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// One account's edits to what the panel sent, resolved into lookups the UI can
/// consult per row without touching the database again.
///
/// Deliberately a plain immutable snapshot rather than a live query: category
/// and channel lists are rebuilt constantly while scrolling, and hitting the DB
/// per row would undo the work that keeps a 25k-channel list fast.
class CatalogOverrides {
  const CatalogOverrides({
    this.hiddenCategories = const {},
    this.hiddenChannels = const {},
    this.categoryNames = const {},
    this.channelNames = const {},
    this.categoryOrder = const {},
  });

  static const empty = CatalogOverrides();

  final Set<String> hiddenCategories;
  final Set<String> hiddenChannels;
  final Map<String, String> categoryNames;
  final Map<String, String> channelNames;

  /// Category id → the position the user put it in.
  final Map<String, int> categoryOrder;

  bool get isEmpty =>
      hiddenCategories.isEmpty &&
      hiddenChannels.isEmpty &&
      categoryNames.isEmpty &&
      channelNames.isEmpty &&
      categoryOrder.isEmpty;

  String categoryName(String id, String fallback) =>
      categoryNames[id] ?? fallback;

  String channelName(String id, String fallback) => channelNames[id] ?? fallback;

  /// Applies hiding, renaming and reordering to a category list in one pass.
  ///
  /// Explicitly-placed categories come first in the user's order; everything
  /// untouched keeps the panel's own order behind them, so ordering a handful
  /// does not shuffle the hundreds that were left alone.
  List<T> applyToCategories<T>(
    List<T> categories, {
    required String Function(T) idOf,
  }) {
    final visible = [
      for (final c in categories)
        if (!hiddenCategories.contains(idOf(c))) c,
    ];
    if (categoryOrder.isEmpty) return visible;
    final indexed = visible.indexed.toList();
    indexed.sort((a, b) {
      final ai = categoryOrder[idOf(a.$2)];
      final bi = categoryOrder[idOf(b.$2)];
      if (ai == null && bi == null) return a.$1.compareTo(b.$1);
      if (ai == null) return 1;
      if (bi == null) return -1;
      return ai.compareTo(bi);
    });
    return [for (final e in indexed) e.$2];
  }
}

/// Reads and writes the user's catalogue edits (schema v11).
class CatalogOverridesRepository {
  CatalogOverridesRepository({required this._db});

  final AppDatabase _db;
  Future<CatalogOverrides> forAccount(String accountId) async {
    final rows = await (_db.catalogOverridesTable.select()
          ..where((t) => t.accountId.equals(accountId)))
        .get();
    if (rows.isEmpty) return CatalogOverrides.empty;

    final hiddenCategories = <String>{};
    final hiddenChannels = <String>{};
    final categoryNames = <String, String>{};
    final channelNames = <String, String>{};
    final categoryOrder = <String, int>{};
    for (final r in rows) {
      final isCategory = r.scope == OverrideScope.category.name;
      if (r.hidden) {
        (isCategory ? hiddenCategories : hiddenChannels).add(r.targetId);
      }
      final name = r.customName;
      if (name != null && name.isNotEmpty) {
        (isCategory ? categoryNames : channelNames)[r.targetId] = name;
      }
      if (isCategory && r.sortIndex != null) {
        categoryOrder[r.targetId] = r.sortIndex!;
      }
    }
    return CatalogOverrides(
      hiddenCategories: hiddenCategories,
      hiddenChannels: hiddenChannels,
      categoryNames: categoryNames,
      channelNames: channelNames,
      categoryOrder: categoryOrder,
    );
  }

  Future<void> setHidden({
    required String accountId,
    required OverrideScope scope,
    required String targetId,
    required bool hidden,
  }) =>
      _upsert(accountId, scope, targetId, hidden: Value(hidden));

  /// An empty or blank [name] clears the override and restores the panel's own.
  Future<void> setName({
    required String accountId,
    required OverrideScope scope,
    required String targetId,
    required String? name,
  }) {
    final trimmed = name?.trim();
    return _upsert(accountId, scope, targetId,
        customName: Value(
            trimmed == null || trimmed.isEmpty ? null : trimmed));
  }

  /// Records [orderedIds] as positions 0..n. Ids left out keep no position and
  /// therefore stay in the panel's order behind the ones placed here.
  Future<void> setCategoryOrder({
    required String accountId,
    required List<String> orderedIds,
  }) async {
    await _db.transaction(() async {
      for (final (index, id) in orderedIds.indexed) {
        await _upsert(accountId, OverrideScope.category, id, sortIndex: Value(index));
      }
    });
  }

  /// Everything back to what the panel says, for one account.
  Future<void> clearAll(String accountId) async {
    await (_db.catalogOverridesTable.delete()
          ..where((t) => t.accountId.equals(accountId)))
        .go();
  }

  Future<void> _upsert(
    String accountId,
    OverrideScope scope,
    String targetId, {
    Value<bool> hidden = const Value.absent(),
    Value<String?> customName = const Value.absent(),
    Value<int?> sortIndex = const Value.absent(),
  }) async {
    // insertOnConflictUpdate would clear the columns this call does not set,
    // so an existing row is updated in place and only created when missing.
    final existing = await (_db.catalogOverridesTable.select()
          ..where((t) =>
              t.accountId.equals(accountId) &
              t.scope.equals(scope.name) &
              t.targetId.equals(targetId)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.catalogOverridesTable.insertOne(
        CatalogOverridesTableCompanion.insert(
          accountId: accountId,
          scope: scope.name,
          targetId: targetId,
          hidden: hidden.present ? Value(hidden.value) : const Value.absent(),
          customName: customName,
          sortIndex: sortIndex,
        ),
      );
    } else {
      await (_db.catalogOverridesTable.update()
            ..where((t) =>
                t.accountId.equals(accountId) &
                t.scope.equals(scope.name) &
                t.targetId.equals(targetId)))
          .write(CatalogOverridesTableCompanion(
        hidden: hidden,
        customName: customName,
        sortIndex: sortIndex,
      ));
    }
  }
}
