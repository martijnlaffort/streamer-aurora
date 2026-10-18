import 'package:flutter/foundation.dart';

/// The clock every last-write-wins stamp is written against.
///
/// Sync resolves conflicts by comparing UTC timestamps written by whichever
/// device made the edit. That is fine until one device's clock is wrong: a
/// phone set a year ahead wins every comparison forever, so it silently
/// overwrites good state on every other device and can never be corrected —
/// its future edits still carry the newest timestamps. With watch progress
/// that costs a resume point. Now that curation syncs it can wipe the hiding
/// of thousands of channels everywhere at once.
///
/// So: learn the truth from the server. Every sync response carries a `Date`
/// header, which is one authoritative clock all devices already talk to. The
/// difference between it and the local clock is the correction applied to
/// every stamp from then on, which puts all devices on the same timebase
/// without changing the protocol or asking the user anything.
///
/// Deliberately NOT a wholesale move to server-side stamping. Edits are made
/// offline and their ORDER matters — "I hid this after I renamed it" — and
/// stamping on receipt would collapse a week of offline edits into whenever
/// the device next got signal.
class ServerClock {
  ServerClock({DateTime Function()? deviceClock})
      : _deviceClock = deviceClock ?? (() => DateTime.now().toUtc());

  final DateTime Function() _deviceClock;

  /// Server time minus device time, or null until a response has been seen.
  Duration? get offset => _offset;
  Duration? _offset;

  /// Below this, the difference is network latency and rounding rather than a
  /// wrong clock, and correcting it would add noise for nothing. `Date` has
  /// one-second resolution, so anything under a few seconds is unmeasurable.
  static const Duration tolerance = Duration(seconds: 30);

  /// Worth telling the user about: a clock this far out will have been writing
  /// bad timestamps for as long as it has been wrong.
  static const Duration alarming = Duration(minutes: 10);

  /// The corrected present. Use this for anything another device will compare.
  DateTime now() {
    final o = _offset;
    return o == null ? _deviceClock() : _deviceClock().add(o);
  }

  /// Whether this device's clock is far enough out to be worth surfacing.
  bool get isSkewed => (_offset ?? Duration.zero).abs() >= alarming;

  /// Records the server's own time, as reported by an HTTP `Date` header.
  ///
  /// [roundTrip] is subtracted in half: the header describes the moment the
  /// server generated the response, which is roughly one leg of the trip ago.
  /// Without that correction every device would read as slightly behind.
  void observe(DateTime serverTime, {Duration roundTrip = Duration.zero}) {
    final measured = serverTime.toUtc().add(roundTrip ~/ 2).difference(
          _deviceClock(),
        );
    if (measured.abs() < tolerance) {
      // Close enough to be the same clock. Pin to zero rather than leaving the
      // previous correction in place, so a fixed clock stops being corrected.
      if (_offset != Duration.zero) _offset = Duration.zero;
      return;
    }
    if (_offset == null || (measured - _offset!).abs() > tolerance) {
      debugPrint('Clock offset vs server: ${measured.inSeconds}s');
    }
    _offset = measured;
  }

  /// Parses an HTTP `Date` header, ignoring anything unparseable — a proxy
  /// that omits or mangles it must not stop the sync it came from.
  static DateTime? parseHttpDate(String? header) {
    if (header == null || header.isEmpty) return null;
    try {
      // RFC 7231 IMF-fixdate: "Sun, 31 Aug 2026 10:04:11 GMT".
      final parts = header.trim().split(' ');
      if (parts.length < 6) return null;
      const months = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
      };
      final day = int.parse(parts[1]);
      final month = months[parts[2]];
      final year = int.parse(parts[3]);
      final time = parts[4].split(':');
      if (month == null || time.length != 3) return null;
      return DateTime.utc(year, month, day, int.parse(time[0]),
          int.parse(time[1]), int.parse(time[2]));
    } on Object {
      return null;
    }
  }
}
