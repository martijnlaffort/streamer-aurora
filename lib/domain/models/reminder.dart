import 'package:equatable/equatable.dart';

/// A programme the user asked to be told about before it starts.
///
/// The guide is read-only without this: you can see that something is on at
/// 20:30 and have no way to act on it.
class Reminder extends Equatable {
  const Reminder({
    required this.id,
    required this.accountId,
    required this.channelId,
    required this.channelName,
    required this.title,
    required this.startsAt,
    required this.notificationId,
    this.leadMinutes = defaultLeadMinutes,
  });

  /// Long enough to reach the sofa, short enough that the programme is the next
  /// thing that happens.
  static const int defaultLeadMinutes = 3;

  /// `account|channel|startMillis`. Derived rather than random so asking twice
  /// for the same programme replaces the reminder instead of stacking two.
  final String id;

  final String accountId;
  final String channelId;

  /// Stored rather than looked up: a reminder has to render (and fire) even if
  /// the channel has since fallen out of the cached catalogue.
  final String channelName;
  final String title;

  /// Programme start, UTC.
  final DateTime startsAt;

  /// How long before [startsAt] the notification fires.
  final int leadMinutes;

  /// The platform notification id. An int because both Android and iOS key
  /// scheduled notifications by one, and it must stay stable to cancel.
  final int notificationId;

  /// When the notification should actually appear.
  DateTime get firesAt => startsAt.subtract(Duration(minutes: leadMinutes));

  static String idFor({
    required String accountId,
    required String channelId,
    required DateTime startsAt,
  }) =>
      '$accountId|$channelId|${startsAt.toUtc().millisecondsSinceEpoch}';

  /// A stable 31-bit id for the platform, derived from [id].
  ///
  /// Android notification ids are ints, so the string key has to be folded down
  /// to one. Kept positive and inside 31 bits because Android treats the id as a
  /// signed int and negative values behave inconsistently across OEM builds.
  static int notificationIdFor(String id) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  @override
  List<Object?> get props => [
        id,
        accountId,
        channelId,
        channelName,
        title,
        startsAt,
        leadMinutes,
        notificationId,
      ];

  @override
  bool get stringify => true;
}
