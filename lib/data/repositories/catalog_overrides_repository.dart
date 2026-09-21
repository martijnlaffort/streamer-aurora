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
    this.epgIds = const {},
    this.customGroups = const {},
    this.groupMembers = const {},
  });

  /// Channel groups the user made, id → (name, order). Deleted groups are
  /// tombstoned rows and are not in here.
  final Map<String, ({String name, int order})> customGroups;

  /// Group id → the channel ids in it, in the user's order.
  final Map<String, List<String>> groupMembers;

  /// Groups in the user's order, for chips and management screens.
  List<({String id, String name})> get orderedGroups {
    final entries = customGroups.entries.toList()
      ..sort((a, b) {
        final byOrder = a.value.order.compareTo(b.value.order);
        return byOrder != 0 ? byOrder : a.value.name.compareTo(b.value.name);
      });
    return [for (final e in entries) (id: e.key, name: e.value.name)];
  }

  static const empty = CatalogOverrides();

  final Set<String> hiddenCategories;
  final Set<String> hiddenChannels;
  final Map<String, String> categoryNames;
  final Map<String, String> channelNames;

  /// Category id → the position the user put it in.
  final Map<String, int> categoryOrder;

  /// Channel id → the XMLTV channel id the user pointed it at, when the
  /// automatic match found nothing or found the wrong thing.
  final Map<String, String> epgIds;

  bool get isEmpty =>
      hiddenCategories.isEmpty &&
      hiddenChannels.isEmpty &&
      categoryNames.isEmpty &&
      channelNames.isEmpty &&
      categoryOrder.isEmpty &&
      epgIds.isEmpty &&
      customGroups.isEmpty &&
      groupMembers.isEmpty;

  /// Which guide key to read a channel's programmes under: the user's mapping
  /// if they set one, otherwise whatever the playlist claimed.
  String epgKey(String channelId, String fallback) =>
      epgIds[channelId] ?? fallback;

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
  CatalogOverridesRepository({
    required this._db,
    DateTime Function()? clock,
    this.onChanged,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Fired after any local edit so the sync coordinator can push promptly.
  ///
  /// Deliberately NOT an invalidate of the overrides provider — that is what
  /// created a top-level provider cycle last time. Callers still invalidate.
  final void Function()? onChanged;
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
    final epgIds = <String, String>{};
    final customGroups = <String, ({String name, int order})>{};
    final members = <({String groupId, String channelId, int order})>[];
    for (final r in rows) {
      // Explicitly three-way. This used to be "category or else channel", so
      // adding a third scope would have filed every EPG mapping as a channel
      // RENAME and put an XMLTV id on screen as the channel's name.
      final scope = OverrideScope.values
          .where((s) => s.name == r.scope)
          .firstOrNull;
      final name = r.customName;
      switch (scope) {
        case OverrideScope.category:
          if (r.hidden) hiddenCategories.add(r.targetId);
          if (name != null && name.isNotEmpty) categoryNames[r.targetId] = name;
          if (r.sortIndex != null) categoryOrder[r.targetId] = r.sortIndex!;
        case OverrideScope.channel:
          if (r.hidden) hiddenChannels.add(r.targetId);
          if (name != null && name.isNotEmpty) channelNames[r.targetId] = name;
        case OverrideScope.epg:
          if (name != null && name.isNotEmpty) epgIds[r.targetId] = name;
        case OverrideScope.group:
          // hidden == deleted: the row stays as a tombstone so the deletion
          // reaches the other devices, but the group is gone from here.
          if (r.hidden || name == null || name.isEmpty) break;
          customGroups[r.targetId] = (name: name, order: r.sortIndex ?? 1 << 20);
        case OverrideScope.groupMember:
          if (r.hidden) break;
          final slash = r.targetId.indexOf('/');
          if (slash <= 0 || slash == r.targetId.length - 1) break;
          members.add((
            groupId: r.targetId.substring(0, slash),
            channelId: r.targetId.substring(slash + 1),
            order: r.sortIndex ?? 1 << 20,
          ));
        case null:
          break; // A scope written by a newer build; ignore rather than guess.
      }
    }
    // Members of a group that has been deleted are dropped with it: their rows
    // may well still exist (deleting a group tombstones the group, not every
    // member), and showing them would resurrect the group in all but name.
    members.sort((a, b) => a.order.compareTo(b.order));
    final groupMembers = <String, List<String>>{};
    for (final m in members) {
      if (!customGroups.containsKey(m.groupId)) continue;
      groupMembers.putIfAbsent(m.groupId, () => []).add(m.channelId);
    }
    return CatalogOverrides(
      hiddenCategories: hiddenCategories,
      hiddenChannels: hiddenChannels,
      categoryNames: categoryNames,
      channelNames: channelNames,
      categoryOrder: categoryOrder,
      epgIds: epgIds,
      customGroups: customGroups,
      groupMembers: groupMembers,
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
  ///
  /// Resets the rows in place rather than deleting them. A delete is invisible
  /// to last-write-wins — the other device still holds its copies, so the next
  /// sync would hand every hidden channel straight back.
  Future<void> clearAll(String accountId) async {
    await (_db.catalogOverridesTable.update()
          ..where((t) => t.accountId.equals(accountId)))
        .write(CatalogOverridesTableCompanion(
      hidden: const Value(false),
      customName: const Value(null),
      sortIndex: const Value(null),
      updatedAtMillisUtc: Value(_clock().millisecondsSinceEpoch),
    ));
    onChanged?.call();
  }

  /// Every row for [accountId], for the sync push.
  Future<List<CatalogOverrideRow>> records(String accountId) =>
      (_db.catalogOverridesTable.select()
            ..where((t) => t.accountId.equals(accountId)))
          .get();

  /// Applies a row pulled from another device. Returns whether it changed
  /// anything here — the caller only rebuilds the UI when something did.
  Future<bool> applyRemote(CatalogOverrideRow remote) async {
    final existing = await (_db.catalogOverridesTable.select()
          ..where((t) =>
              t.accountId.equals(remote.accountId) &
              t.scope.equals(remote.scope) &
              t.targetId.equals(remote.targetId)))
        .getSingleOrNull();
    // Ties go to the local row: re-applying an edit we already have would
    // churn the providers on every sync for no visible change.
    if (existing != null &&
        (existing.updatedAtMillisUtc ?? 0) >=
            (remote.updatedAtMillisUtc ?? 0)) {
      return false;
    }
    await _db.catalogOverridesTable.insertOnConflictUpdate(remote);
    return true;
  }

  // --- Custom groups ---------------------------------------------------------
  //
  // A group is an override row of scope `group`; its members are rows of scope
  // `groupMember` keyed `<groupId>/<channelId>`. Nothing new to sync: they are
  // curation, and they ride the same last-write-wins table as hiding and
  // renaming, so a group made on the phone is on the television next sync.

  /// Makes a new, empty group and returns its id.
  ///
  /// The id is the creation instant rather than a counter: two devices making
  /// a group offline must not collide when they later sync, and a millisecond
  /// timestamp per user is unique enough for that without coordination.
  Future<String> createGroup({
    required String accountId,
    required String name,
  }) async {
    final id = 'g${_clock().millisecondsSinceEpoch}';
    final existing = await forAccount(accountId);
    await _upsert(accountId, OverrideScope.group, id,
        customName: Value(name.trim()),
        sortIndex: Value(existing.customGroups.length),
        hidden: const Value(false));
    return id;
  }

  Future<void> renameGroup({
    required String accountId,
    required String groupId,
    required String name,
  }) =>
      _upsert(accountId, OverrideScope.group, groupId,
          customName: Value(name.trim()));

  /// Tombstones the group. Its member rows are left alone: the loader drops
  /// members of a group it cannot find, and deleting them individually would
  /// be one write per channel for no visible difference.
  Future<void> deleteGroup({
    required String accountId,
    required String groupId,
  }) =>
      _upsert(accountId, OverrideScope.group, groupId,
          hidden: const Value(true));

  Future<void> setGroupOrder({
    required String accountId,
    required List<String> orderedIds,
  }) async {
    await _db.transaction(() async {
      for (final (index, id) in orderedIds.indexed) {
        await _upsert(accountId, OverrideScope.group, id,
            sortIndex: Value(index));
      }
    });
  }

  /// Adds [channelId] at the end of [groupId]. Re-adding a removed channel
  /// clears its tombstone.
  Future<void> addToGroup({
    required String accountId,
    required String groupId,
    required String channelId,
  }) async {
    final existing = await forAccount(accountId);
    final position = existing.groupMembers[groupId]?.length ?? 0;
    await _upsert(accountId, OverrideScope.groupMember, '$groupId/$channelId',
        hidden: const Value(false), sortIndex: Value(position));
  }

  Future<void> removeFromGroup({
    required String accountId,
    required String groupId,
    required String channelId,
  }) =>
      _upsert(accountId, OverrideScope.groupMember, '$groupId/$channelId',
          hidden: const Value(true));

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
    final stamp = Value(_clock().millisecondsSinceEpoch);
    if (existing == null) {
      await _db.catalogOverridesTable.insertOne(
        CatalogOverridesTableCompanion.insert(
          accountId: accountId,
          scope: scope.name,
          targetId: targetId,
          hidden: hidden.present ? Value(hidden.value) : const Value.absent(),
          customName: customName,
          sortIndex: sortIndex,
          updatedAtMillisUtc: stamp,
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
        updatedAtMillisUtc: stamp,
      ));
    }
    onChanged?.call();
  }
}
