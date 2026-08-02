import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../domain/entities/common_enums.dart';
import '../../../domain/entities/reminder.dart';
import 'reminder_schedule.dart';

/// Per-launch notification presentation options merged with each reminder's
/// own settings before a notification is scheduled.
class ReminderNotificationOptions {
  const ReminderNotificationOptions({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.silentMode = false,
  });

  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool silentMode;
}

/// Action identifiers exposed on Android notification action buttons.
abstract final class NotificationActions {
  static const String complete = 'complete';
  static const String skip = 'skip';
}

/// Thin wrapper around [FlutterLocalNotificationsPlugin] that schedules the
/// full reminder module's local notifications.
///
/// Supports one-time, daily, weekly, monthly and custom-day schedules plus
/// multiple times per day, sound/vibration/silent configuration, action
/// buttons and a payload that opens the related screen when tapped. Scheduling
/// is a no-op on web (unsupported) and every platform call is guarded so a
/// failure can never crash the app.
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance =
      LocalNotificationService._();

  /// Notifications are not available on web.
  static bool get isSupported => !kIsWeb;

  /// Invoked when the user taps a notification (actionId null) or presses an
  /// action button (actionId = complete/skip). Payload carries the reminder id.
  void Function(String? actionId, int reminderId)? onNotificationAction;

  /// Small icon drawable used on Android.
  static const String _smallIcon = '@drawable/ic_stat_notify';

  /// Notification channel. High importance on some OEM skins (MIUI, Samsung)
  /// labels the notification "urgent", so reminders use default importance and
  /// auto-cancel after [toastTimeoutMs] to behave like a short-lived toast.
  static const String _channelId = 'reminders_v2';
  static const String _channelName = 'Reminders';
  static const String _channelDescription = 'Your scheduled reminders';
  static const int _toastTimeoutMs = 5000;
  /// Legacy channel id used before the toast-like behaviour was introduced;
  /// removed on init so devices don't keep a stale high-importance channel.
  static const String _legacyChannelId = 'reminders';

  static const int _slotFactor = 10000;
  static const int _dailyBase = 0;
  static const int _oneTimeBase = 1000;
  static const int _monthlyBase = 2000;
  static const int _weekdayBase = 3000;
  static const int _maxSlots = 10;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Prepares timezone data and the plugin. Safe to call more than once.
  Future<void> initialize() async {
    if (!isSupported || _initialized) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final String tzName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(tzName));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      const InitializationSettings settings = InitializationSettings(
        android: AndroidInitializationSettings(_smallIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      );
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onResponse,
        onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
      );
      _initialized = true;

      // Remove the old high-importance channel so the recreated one picks up
      // the default importance instead of keeping the "urgent" label.
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.deleteNotificationChannel(_legacyChannelId);
    } catch (_) {
      _initialized = false;
    }
  }

  /// Asks the OS for notification permission (Android 13+ / iOS).
  Future<void> requestPermission() async {
    if (!isSupported) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {
      // Permission prompts are best-effort.
    }
  }

  /// Schedules every upcoming occurrence of [reminder] with the given global
  /// [options]. Repeating daily/weekly/custom-day schedules use platform
  /// matching so they keep firing without the app being opened; one-time and
  /// monthly schedules fire the next occurrence(s) and are re-synced on launch.
  Future<void> scheduleReminder(
    Reminder reminder, {
    ReminderNotificationOptions options =
        const ReminderNotificationOptions(),
  }) async {
    if (!isSupported || !_initialized || !reminder.isEnabled) return;
    final int id = reminder.id ?? 0;
    final bool sound =
        !options.silentMode &&
        options.soundEnabled &&
        reminder.soundEnabled &&
        !reminder.silentMode;
    final bool vibrate =
        !options.silentMode &&
        options.vibrationEnabled &&
        reminder.vibrationEnabled &&
        !reminder.silentMode;
    final bool showActions = reminder.showActionButtons && !options.silentMode;

    final List<String> times = reminder.allTimes;
    switch (reminder.scheduleType) {
      case ReminderScheduleType.oneTime:
        for (int slot = 0; slot < times.length; slot++) {
          final DateTime? next = nextReminderOccurrence(reminder, DateTime.now());
          if (next == null) continue;
          await _plugin.zonedSchedule(
            _idForSlot(id, _oneTimeBase, slot),
            reminder.title,
            reminder.body ?? '',
            _toTz(next),
            _details(reminder, sound: sound, vibrate: vibrate, showActions: showActions),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: '$id',
          );
        }
      case ReminderScheduleType.daily:
        for (int slot = 0; slot < times.length; slot++) {
          final (int hour, int minute) = parseHhmm(times[slot]);
          await _plugin.zonedSchedule(
            _idForSlot(id, _dailyBase, slot),
            reminder.title,
            reminder.body ?? '',
            _nextDaily(hour, minute),
            _details(reminder, sound: sound, vibrate: vibrate, showActions: showActions),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: '$id',
          );
        }
      case ReminderScheduleType.weekly:
        for (int slot = 0; slot < times.length; slot++) {
          final (int hour, int minute) = parseHhmm(times[slot]);
          for (final int day in reminder.daysOfWeek) {
            await _plugin.zonedSchedule(
              _idForSlot(id, _weekdayBase, slot * 10 + day),
              reminder.title,
              reminder.body ?? '',
              _nextWeekday(hour, minute, day),
              _details(reminder, sound: sound, vibrate: vibrate, showActions: showActions),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              payload: '$id',
            );
          }
        }
      case ReminderScheduleType.customDays:
        for (int slot = 0; slot < times.length; slot++) {
          final (int hour, int minute) = parseHhmm(times[slot]);
          for (final int day in reminder.daysOfWeek) {
            await _plugin.zonedSchedule(
              _idForSlot(id, _weekdayBase, slot * 10 + day),
              reminder.title,
              reminder.body ?? '',
              _nextWeekday(hour, minute, day),
              _details(reminder, sound: sound, vibrate: vibrate, showActions: showActions),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              payload: '$id',
            );
          }
        }
      case ReminderScheduleType.monthly:
        // Schedule the next few monthly occurrences explicitly; the app
        // re-syncs the schedule on each launch.
        for (int slot = 0; slot < times.length; slot++) {
          DateTime cursor = DateTime.now();
          for (int i = 0; i < 6; i++) {
            final DateTime? next = nextReminderOccurrence(reminder, cursor);
            if (next == null) break;
            await _plugin.zonedSchedule(
              _idForSlot(id, _monthlyBase, slot * 100 + i),
              reminder.title,
              reminder.body ?? '',
              _toTz(next),
              _details(reminder, sound: sound, vibrate: vibrate, showActions: showActions),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              payload: '$id',
            );
            cursor = next.add(const Duration(days: 1));
          }
        }
    }
  }

  /// Cancels every notification that could belong to [id].
  Future<void> cancelReminder(int id) async {
    if (!isSupported || !_initialized) return;
    try {
      for (int slot = 0; slot < _maxSlots; slot++) {
        await _plugin.cancel(_idForSlot(id, _dailyBase, slot));
        await _plugin.cancel(_idForSlot(id, _oneTimeBase, slot));
        await _plugin.cancel(_idForSlot(id, _monthlyBase, slot * 100));
        for (int day = 1; day <= 7; day++) {
          await _plugin.cancel(_idForSlot(id, _weekdayBase, slot * 10 + day));
        }
      }
    } catch (_) {
      // Cancelling an unknown id is harmless.
    }
  }

  /// Removes every scheduled notification.
  Future<void> cancelAll() async {
    if (!isSupported || !_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  int _idForSlot(int reminderId, int base, int slot) {
    return reminderId * _slotFactor + base + slot;
  }

  void _onResponse(NotificationResponse response) {
    _dispatch(response);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundResponse(NotificationResponse response) {
    // Background callbacks cannot touch the UI; record the payload for the
    // foreground handler to pick up on next launch.
    _pendingPayload = response.payload;
    _pendingAction = response.actionId;
  }

  static String? _pendingPayload;
  static String? _pendingAction;

  /// Returns any notification tapped while the app was terminated.
  static (String? payload, String? actionId) takePendingTap() {
    final (String?, String?) pending = (_pendingPayload, _pendingAction);
    _pendingPayload = null;
    _pendingAction = null;
    return pending;
  }

  void _dispatch(NotificationResponse response) {
    final int? id = int.tryParse(response.payload ?? '');
    if (id == null) return;
    onNotificationAction?.call(response.actionId, id);
  }

  NotificationDetails _details(
    Reminder reminder, {
    required bool sound,
    required bool vibrate,
    required bool showActions,
  }) {
    final int? colorValue = reminder.colorValue;

    final List<AndroidNotificationAction> actions = showActions
        ? <AndroidNotificationAction>[
            AndroidNotificationAction(
              NotificationActions.complete,
              'Complete',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              NotificationActions.skip,
              'Skip',
              showsUserInterface: true,
            ),
          ]
        : const <AndroidNotificationAction>[];

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: sound,
          enableVibration: vibrate,
          color: colorValue != null ? Color(colorValue) : null,
          icon: _smallIcon,
          largeIcon: const DrawableResourceAndroidBitmap('mipmap/ic_launcher'),
          actions: actions,
          timeoutAfter: _toastTimeoutMs,
          styleInformation: BigTextStyleInformation(
            reminder.body ?? '',
            contentTitle: reminder.title,
            summaryText: _summaryFor(reminder),
          ),
        );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );
  }

  String _summaryFor(Reminder reminder) {
    final String typeName = reminder.reminderType.name;
    final String times = reminder.allTimes.join(', ');
    return '$typeName · $times';
  }

  tz.TZDateTime _toTz(DateTime value) {
    return tz.TZDateTime.from(value, tz.local);
  }

  tz.TZDateTime _nextDaily(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextWeekday(int hour, int minute, int weekday) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    final int difference = weekday - scheduled.weekday;
    scheduled = scheduled.add(Duration(days: difference % 7));
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }
}
