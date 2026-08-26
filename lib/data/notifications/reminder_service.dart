import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/models/reminder.dart';
import '../repositories/reminders_repository.dart';

/// Schedules and cancels the OS-level alarms behind programme reminders.
///
/// The alarm belongs to the operating system, not to this app: that is the
/// whole point — a reminder has to fire with Dawn Player closed, which is when
/// people actually need it.
class ReminderService {
  ReminderService({required this._repository});

  final RemindersRepository _repository;
  final _plugin = FlutterLocalNotificationsPlugin();

  /// Channel ids the user sees in Android's notification settings.
  static const _androidChannelId = 'dawnplayer.reminders';
  static const _androidChannelName = 'Programme reminders';

  /// Emits the channel id of a reminder the user tapped, so the app can open it.
  Stream<String> get taps => _taps.stream;
  final _taps = StreamController<String>.broadcast();

  bool _ready = false;

  /// Whether this platform can schedule at all. Desktop builds have no
  /// implementation here, and pretending otherwise would surface a "Remind me"
  /// button that silently does nothing.
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  Future<void> init() async {
    if (_ready || !isSupported) return;
    // The plugin schedules against a real timezone, not a raw UTC offset, so
    // a reminder set before a DST change still fires at the right wall time.
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await _localTimezoneName()));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for at the point the user sets their first reminder instead,
          // where the prompt has a reason attached to it.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _taps.add(payload);
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: 'Tells you when a programme you asked about is starting',
          importance: Importance.high,
        ));
    _ready = true;
  }

  /// Asks for permission, returning whether reminders can actually be posted.
  ///
  /// Called when the user sets one rather than at launch: a notification prompt
  /// on first run, before the app has ever needed to notify anything, is the
  /// kind people refuse by reflex.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await init();
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? false;
      // Exact alarms are a separate grant on Android 13+. Without it the
      // plugin's exact schedule throws, so fall back rather than fail.
      await android?.requestExactAlarmsPermission();
      return granted;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true, badge: true) ??
        false;
  }

  /// Arms the OS alarm for [reminder]. Returns false when the moment has
  /// already passed, so callers can say so instead of silently doing nothing.
  Future<bool> schedule(Reminder reminder) async {
    if (!isSupported) return false;
    await init();
    final when = tz.TZDateTime.from(reminder.firesAt.toLocal(), tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return false;
    Future<void> post(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id: reminder.notificationId,
          title: reminder.title,
          body: 'Starting now on ${reminder.channelName}',
          scheduledDate: when,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannelId,
              _androidChannelName,
              importance: Importance.high,
              priority: Priority.high,
              category: AndroidNotificationCategory.event,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: mode,
          payload: reminder.channelId,
        );
    try {
      await post(AndroidScheduleMode.exactAllowWhileIdle);
      return true;
    } on Object catch (e) {
      // Exact alarms can be refused — the permission above is deniable, and
      // some OEM builds refuse regardless. A reminder that lands a few minutes
      // late beats no reminder at all, so fall back rather than fail.
      debugPrint('Exact reminder rejected ($e); scheduling inexact.');
      try {
        await post(AndroidScheduleMode.inexactAllowWhileIdle);
        return true;
      } on Object catch (e) {
        debugPrint('Reminder could not be scheduled: $e');
        return false;
      }
    }
  }

  Future<void> cancel(Reminder reminder) async {
    if (!isSupported) return;
    await init();
    await _plugin.cancel(id: reminder.notificationId);
  }

  /// Re-arms everything still due and forgets what has passed.
  ///
  /// Android drops scheduled alarms on reboot and on some app updates, and the
  /// boot receiver only restores what the plugin itself still knows about — so
  /// the stored rows are the source of truth, and this runs at every launch.
  Future<void> restoreAll() async {
    if (!isSupported) return;
    await init();
    final now = DateTime.now().toUtc();
    await _repository.pruneBefore(now);
    for (final reminder in await _repository.upcoming(now)) {
      await schedule(reminder);
    }
  }

  /// A reminder the user tapped while the app was not running.
  Future<String?> launchPayload() async {
    if (!isSupported) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final payload = details?.notificationResponse?.payload;
    return (payload != null && payload.isNotEmpty) ? payload : null;
  }

  Future<String> _localTimezoneName() async {
    try {
      // The IANA name the device is actually set to; `tz` needs that rather
      // than an offset to get DST transitions right.
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } on Object {
      return 'UTC';
    }
  }

  void dispose() => _taps.close();
}
