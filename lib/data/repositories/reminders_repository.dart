import 'package:drift/drift.dart';

import '../../domain/models/reminder.dart';
import '../db/app_database.dart';

/// Stored programme reminders.
///
/// Local-only by design: the row exists to survive a restart and to re-arm the
/// OS alarm after a reboot, which Android clears. It is not part of the sync
/// payload — see the schema v14 note.
class RemindersRepository {
  RemindersRepository({required this._db});

  final AppDatabase _db;

  Future<List<Reminder>> all() async {
    final rows = await (_db.select(_db.remindersTable)
          ..orderBy([(t) => OrderingTerm.asc(t.startsAtMillisUtc)]))
        .get();
    return rows.map(_toModel).toList();
  }

  /// Everything still ahead of [now], oldest first.
  Future<List<Reminder>> upcoming(DateTime now) async {
    final rows = await (_db.select(_db.remindersTable)
          ..where((t) =>
              t.startsAtMillisUtc.isBiggerThanValue(now.toUtc().millisecondsSinceEpoch))
          ..orderBy([(t) => OrderingTerm.asc(t.startsAtMillisUtc)]))
        .get();
    return rows.map(_toModel).toList();
  }

  Future<bool> exists(String id) async {
    final row = await (_db.select(_db.remindersTable)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Insert or replace — the id is derived from the programme, so asking twice
  /// is an update rather than a duplicate.
  Future<void> save(Reminder reminder) =>
      _db.into(_db.remindersTable).insertOnConflictUpdate(
            RemindersTableCompanion.insert(
              id: reminder.id,
              accountId: reminder.accountId,
              channelId: reminder.channelId,
              channelName: reminder.channelName,
              title: reminder.title,
              startsAtMillisUtc:
                  reminder.startsAt.toUtc().millisecondsSinceEpoch,
              leadMinutes: Value(reminder.leadMinutes),
              notificationId: reminder.notificationId,
            ),
          );

  Future<void> remove(String id) =>
      (_db.delete(_db.remindersTable)..where((t) => t.id.equals(id))).go();

  /// Drops reminders whose programme has already started.
  ///
  /// Called on launch: without it the table grows forever, and the reminders
  /// screen fills up with things that already happened.
  Future<void> pruneBefore(DateTime cutoff) =>
      (_db.delete(_db.remindersTable)
            ..where((t) => t.startsAtMillisUtc
                .isSmallerThanValue(cutoff.toUtc().millisecondsSinceEpoch)))
          .go();

  Reminder _toModel(ReminderRow row) => Reminder(
        id: row.id,
        accountId: row.accountId,
        channelId: row.channelId,
        channelName: row.channelName,
        title: row.title,
        startsAt:
            DateTime.fromMillisecondsSinceEpoch(row.startsAtMillisUtc, isUtc: true),
        leadMinutes: row.leadMinutes,
        notificationId: row.notificationId,
      );
}
