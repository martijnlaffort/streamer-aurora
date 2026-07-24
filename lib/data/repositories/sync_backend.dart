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
  Future<void> push(Preferences preferences);
  Future<Preferences?> pull();
}

abstract interface class FavoritesSyncBackend {
  Future<void> push(List<String> contentKeys);
  Future<List<String>> pull();
}
