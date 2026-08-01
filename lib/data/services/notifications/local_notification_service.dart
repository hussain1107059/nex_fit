import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around [FlutterLocalNotificationsPlugin] used to schedule the
/// hydration reminders. Scheduling is a no-op on web (unsupported) and the
/// service silently guards every platform call so a failure can never crash
/// the app.
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance =
      LocalNotificationService._();

  /// Notifications are not available on web.
  static bool get isSupported => !kIsWeb;

  static const int _dailyIdOffset = 0;
  static const int _weeklyIdFactor = 1000;

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
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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
      await _plugin.initialize(settings);
      _initialized = true;
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

  /// Schedules a repeating reminder.
  ///
  /// [id] is the reminder's database id, [time] a "HH:mm" 24h string and
  /// [daysOfWeek] weekday numbers 1 (Monday) .. 7 (Sunday); empty means daily.
  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required String time,
    List<int> daysOfWeek = const <int>[],
  }) async {
    if (!isSupported || !_initialized) return;
    final (int hour, int minute) = _parseTime(time);

    if (daysOfWeek.isEmpty) {
      final tz.TZDateTime next = _nextInstance(hour, minute, null);
      await _plugin.zonedSchedule(
        _dailyIdOffset + id,
        title,
        body,
        next,
        _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return;
    }

    for (final int day in daysOfWeek) {
      final int notificationId = id * _weeklyIdFactor + day;
      final tz.TZDateTime next = _nextInstance(hour, minute, day);
      await _plugin.zonedSchedule(
        notificationId,
        title,
        body,
        next,
        _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Cancels every notification that [scheduleDaily] would create for [id].
  Future<void> cancelReminder(int id) async {
    if (!isSupported || !_initialized) return;
    try {
      await _plugin.cancel(_dailyIdOffset + id);
      for (int day = 1; day <= 7; day++) {
        await _plugin.cancel(id * _weeklyIdFactor + day);
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

  tz.TZDateTime _nextInstance(int hour, int minute, int? weekday) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (weekday != null) {
      final int difference = weekday - scheduled.weekday;
      scheduled = scheduled.add(Duration(days: difference % 7));
    }
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  (int, int) _parseTime(String time) {
    final List<String> parts = time.split(':');
    final int hour = int.tryParse(parts.isEmpty ? '' : parts[0]) ?? 8;
    final int minute = parts.length < 2 ? 0 : (int.tryParse(parts[1]) ?? 0);
    return (hour.clamp(0, 23), minute.clamp(0, 59));
  }

  NotificationDetails _details() {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'hydration_reminders',
          'Hydration Reminders',
          channelDescription: 'Daily reminders to drink enough water',
          importance: Importance.high,
          priority: Priority.high,
        );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );
  }
}
