import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// Remembers which of a channel's streams last actually played.
///
/// A line ships the same channel several times and they are not equally
/// healthy: the 4K row can be dead for a week while the HD one works. Failover
/// finds the working one, and this stops the next tune-in paying for that walk
/// all over again.
class StreamChoiceRepository {
  StreamChoiceRepository({required this.db, DateTime Function()? clock})
      : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase db;
  final DateTime Function() _clock;

  /// How long a remembered choice is trusted.
  ///
  /// Deliberately short. The memory exists to skip a walk we already did today,
  /// not to permanently demote the best feed because it was briefly down — a
  /// provider that fixes its 4K row overnight should get it back, without the
  /// user ever knowing there was anything to fix.
  static const Duration ttl = Duration(hours: 24);

  /// The stream to try FIRST for [variantKey], or null when there is no fresh
  /// memory and the best-quality one should lead.
  Future<String?> preferred(String accountId, String variantKey) async {
    final row = await (db.select(db.streamChoicesTable)
          ..where((t) =>
              t.accountId.equals(accountId) & t.variantKey.equals(variantKey)))
        .getSingleOrNull();
    if (row == null) return null;
    final chosenAt =
        DateTime.fromMillisecondsSinceEpoch(row.chosenAtMillisUtc, isUtc: true);
    if (_clock().difference(chosenAt) > ttl) return null;
    return row.streamId;
  }

  Future<void> remember({
    required String accountId,
    required String variantKey,
    required String streamId,
  }) =>
      db.into(db.streamChoicesTable).insertOnConflictUpdate(
            StreamChoicesTableCompanion.insert(
              accountId: accountId,
              variantKey: variantKey,
              streamId: streamId,
              chosenAtMillisUtc: _clock().millisecondsSinceEpoch,
            ),
          );
}
