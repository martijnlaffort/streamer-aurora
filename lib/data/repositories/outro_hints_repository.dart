import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// Learns where a show's credits start from when the user skips ahead.
///
/// Netflix knows where an episode's outro begins because someone tagged it. An
/// IPTV panel hands us a URL and a length, nothing more. But outros are
/// consistent within a show, and a viewer pressing "next episode" at the same
/// distance from the end three times running has told us where the credits
/// are. This remembers that, per series, and hands it back as the moment to
/// offer the next episode.
class OutroHintsRepository {
  OutroHintsRepository({required this.db, DateTime Function()? clock})
      : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase db;
  final DateTime Function() _clock;

  /// How many observations to keep per series. Enough to shrug off one odd
  /// press, few enough that a show whose credits change length adapts.
  static const int keep = 5;

  /// Bounds on what counts as a plausible outro. Below the floor it is the
  /// last scene; above the ceiling it is someone bailing on the episode.
  static const int minSeconds = 15;
  static const int maxSeconds = 10 * 60;

  /// Seconds before the end to offer the next episode, or null when this
  /// series has not taught us anything yet.
  ///
  /// The MEDIAN of the recent presses, not the mean: one early exit must not
  /// drag the prompt forward for every episode after it.
  Future<int?> secondsBeforeEnd(String accountId, String seriesId) async {
    final rows = await (db.select(db.outroHintsTable)
          ..where((t) =>
              t.accountId.equals(accountId) & t.seriesId.equals(seriesId))
          ..orderBy([(t) => OrderingTerm.desc(t.observedAtMillisUtc)])
          ..limit(keep))
        .get();
    if (rows.length < 2) return null; // One press is an accident, not a pattern.
    final sorted = [for (final r in rows) r.secondsBeforeEnd]..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// The user moved on with [secondsBeforeEnd] still to play.
  Future<void> record({
    required String accountId,
    required String seriesId,
    required int secondsBeforeEnd,
  }) async {
    if (secondsBeforeEnd < minSeconds || secondsBeforeEnd > maxSeconds) return;
    await db.into(db.outroHintsTable).insert(OutroHintsTableCompanion.insert(
          accountId: accountId,
          seriesId: seriesId,
          secondsBeforeEnd: secondsBeforeEnd,
          observedAtMillisUtc: _clock().millisecondsSinceEpoch,
        ));
    // Keep only the newest [keep]; the table must not grow with every episode.
    final stale = await (db.select(db.outroHintsTable)
          ..where((t) =>
              t.accountId.equals(accountId) & t.seriesId.equals(seriesId))
          ..orderBy([(t) => OrderingTerm.desc(t.observedAtMillisUtc)]))
        .get();
    if (stale.length > keep) {
      final ids = [for (final r in stale.skip(keep)) r.id];
      await (db.delete(db.outroHintsTable)..where((t) => t.id.isIn(ids))).go();
    }
  }
}
