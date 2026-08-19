import '../../domain/models/models.dart';

/// The sync seam (PRD §9). Local is always the source of truth; when a
/// backend is configured (Phase 2, thin Laravel API), a background reconciler
/// implements these and repositories push/pull through them with
/// last-write-wins by `updatedAt` (UTC). Nothing implements them yet —
/// repositories accept them as optional and behave purely locally when null.
abstract interface class ProgressSyncBackend {
  Future<void> push(List<WatchProgress> entries);

  /// Entries changed on the backend since [since] (null = everything).
  Future<List<WatchProgress>> pullSince(DateTime? since);
}

abstract interface class PreferencesSyncBackend {
  /// [updatedAt] is when the prefs last changed locally — the server keeps the
  /// newer of the two (last-write-wins).
  Future<void> push(Preferences preferences, DateTime updatedAt);

  /// The authoritative prefs and their `updatedAt`, or null when the server
  /// has none yet.
  Future<({Preferences prefs, DateTime updatedAt})?> pull();
}

/// One favourite as it travels through sync: last-write-wins per [contentKey],
/// with [removed] carrying a deletion so it propagates like an add.
typedef FavoriteRecord = ({
  String contentKey,
  bool removed,
  DateTime addedAt,
  DateTime updatedAt,
});

abstract interface class FavoritesSyncBackend {
  /// Upserts [records] on the server (last-write-wins by updatedAt).
  Future<void> push(List<FavoriteRecord> records);

  /// Every record, active and tombstoned.
  Future<List<FavoriteRecord>> pull();
}

/// One playlist/account as it travels through sync. The password rides along —
/// a playlist is useless without it — so this is only ever sent to the user's
/// own backend over TLS.
typedef AccountRecord = ({
  String accountId,
  String type,
  String name,
  String serverUrl,
  String username,
  String password,
  String? epgUrl,
  DateTime updatedAt,
});

abstract interface class AccountSyncBackend {
  Future<void> push(List<AccountRecord> records);
  Future<List<AccountRecord>> pull();
}
