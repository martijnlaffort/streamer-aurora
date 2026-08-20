import 'package:drift/drift.dart';

import '../../domain/models/models.dart';
import '../db/app_database.dart';
import '../db/mappers.dart';
import 'sync_backend.dart';

/// Watch progress, local-first with a sync seam (PRD §8.9, §9). Local is the
/// source of truth; when a [ProgressSyncBackend] exists (Phase 2), a
/// reconciler pushes rows with `syncedAt == null` and pulls newer ones —
/// last-write-wins by `updatedAt` (UTC).
class WatchProgressRepository {
  WatchProgressRepository({
    required this._db,
    DateTime Function()? clock,
    this.onChanged,
    // Accepted but unused until the Phase 2 backend exists.
    // ignore: avoid_unused_constructor_parameters
    ProgressSyncBackend? backend,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Called after a local write, so automatic sync can push it soon. Null in
  /// tests / when auto-sync is not wired.
  final void Function()? onChanged;

  /// Resume window per PRD §8.9: outside 5%..95% counts as fresh/finished.
  static const double resumeMinFraction = 0.05;
  static const double resumeMaxFraction = 0.95;

  /// Upserts the position for [contentKey], stamping `updatedAt` now (UTC)
  /// and clearing `syncedAt` (the row is dirty again). Applies the §8.9
  /// completion rule automatically.
  Future<WatchProgress> savePosition({
    required String contentKey,
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    final completed = durationSeconds > 0 &&
        positionSeconds / durationSeconds >= resumeMaxFraction;
    final progress = WatchProgress(
      contentKey: contentKey,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
      updatedAt: _clock(),
      completed: completed,
    );
    await _db.watchProgressTable.insertOnConflictUpdate(progress.toCompanion());
    onChanged?.call();
    return progress;
  }

  Future<WatchProgress?> get(String contentKey) async {
    final row = await (_db.watchProgressTable.select()
          ..where((t) => t.contentKey.equals(contentKey)))
        .getSingleOrNull();
    return row?.toModel();
  }

  /// Whether the §8.9 window says this progress warrants a Resume offer.
  bool shouldOfferResume(WatchProgress? progress) {
    if (progress == null || progress.completed) return false;
    if (progress.durationSeconds <= 0) return false;
    final fraction = progress.positionSeconds / progress.durationSeconds;
    return fraction > resumeMinFraction && fraction < resumeMaxFraction;
  }

  /// The Continue Watching rail: unfinished items, most recent first
  /// (PRD §8.9: sorted by `updated_at` desc).
  Future<List<WatchProgress>> continueWatching({int limit = 20}) async {
    final rows = await (_db.watchProgressTable.select()
          ..where((t) => t.completed.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAtMillisUtc)])
          ..limit(limit))
        .get();
    return rows.map((r) => r.toModel()).toList();
  }

  /// Recently touched progress, finished or not, most recent first.
  ///
  /// [continueWatching] hides completed rows, which is right for a film but
  /// wrong for a series: finishing an episode made the whole show vanish from
  /// the rail instead of advancing to the next episode. Home uses this to find
  /// the next one up. The default limit is generous because entries get
  /// filtered and de-duplicated afterwards.
  Future<List<WatchProgress>> recentlyWatched({int limit = 60}) async {
    final rows = await (_db.watchProgressTable.select()
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAtMillisUtc)])
          ..limit(limit))
        .get();
    return rows.map((r) => r.toModel()).toList();
  }

  /// Marks content finished and drops it from Continue Watching.
  Future<void> markCompleted(String contentKey) async {
    await (_db.watchProgressTable.update()
          ..where((t) => t.contentKey.equals(contentKey)))
        .write(WatchProgressTableCompanion(
      completed: const Value(true),
      updatedAtMillisUtc: Value(utcMillis(_clock())),
      syncedAtMillisUtc: const Value(null),
    ));
    onChanged?.call();
  }

  Future<void> remove(String contentKey) async {
    await (_db.watchProgressTable.delete()
          ..where((t) => t.contentKey.equals(contentKey)))
        .go();
  }

  /// Rows the reconciler pushes (dirty = never synced since the last local
  /// write).
  Future<List<WatchProgress>> unsyncedEntries() async {
    final rows = await (_db.watchProgressTable.select()
          ..where((t) => t.syncedAtMillisUtc.isNull()))
        .get();
    return rows.map((r) => r.toModel()).toList();
  }

  /// Applies a remote entry the reconciler judged newer, marking it synced so
  /// it isn't immediately pushed back (PRD §9 last-write-wins).
  Future<void> applyRemote(WatchProgress remote) async {
    await _db.watchProgressTable.insertOnConflictUpdate(
      WatchProgressTableCompanion.insert(
        contentKey: remote.contentKey,
        positionSeconds: remote.positionSeconds,
        durationSeconds: remote.durationSeconds,
        updatedAtMillisUtc: utcMillis(remote.updatedAt),
        syncedAtMillisUtc: Value(utcMillis(_clock())),
        completed: Value(remote.completed),
      ),
    );
  }

  /// Marks the pushed [entries] synced — but only rows still at the pushed
  /// `updatedAt`. If a local save bumped a row's `updatedAt` between the push
  /// snapshot and here, that row stays dirty and is pushed on the next sync, so
  /// a concurrent write is never silently lost (PRD §9).
  Future<void> markSynced(Iterable<WatchProgress> entries) async {
    final now = utcMillis(_clock());
    for (final e in entries) {
      await (_db.watchProgressTable.update()
            ..where((t) =>
                t.contentKey.equals(e.contentKey) &
                t.updatedAtMillisUtc.equals(utcMillis(e.updatedAt))))
          .write(WatchProgressTableCompanion(syncedAtMillisUtc: Value(now)));
    }
  }
}
