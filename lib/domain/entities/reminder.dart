import 'package:equatable/equatable.dart';

import 'common_enums.dart';

/// A scheduled reminder for a recurring habit.
///
/// [time] is the primary "HH:mm" 24h time of day; [times] may carry additional
/// times for reminders that fire multiple times per day. When [times] is empty
/// the reminder fires once per day at [time].
class Reminder extends Equatable {
  const Reminder({
    this.id,
    required this.userId,
    required this.title,
    this.body,
    this.reminderType = ReminderType.custom,
    required this.time,
    this.daysOfWeek = const <int>[],
    this.scheduleType = ReminderScheduleType.daily,
    this.times = const <String>[],
    this.startDate,
    this.endDate,
    this.monthDay,
    this.icon,
    this.colorValue,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.silentMode = false,
    this.showActionButtons = true,
    this.relatedScreen,
    this.isEnabled = true,
    this.lastTriggeredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String userId;
  final String title;
  final String? body;
  final ReminderType reminderType;

  /// Primary reminder time of day as a 24h "HH:mm" string.
  final String time;

  /// Weekday list 1 (Monday) .. 7 (Sunday); empty means every day for daily
  /// schedules and carries the selected weekdays for weekly / custom days.
  final List<int> daysOfWeek;

  /// How the reminder repeats.
  final ReminderScheduleType scheduleType;

  /// Additional "HH:mm" times for multi-time-per-day reminders.
  final List<String> times;

  /// First date a [ReminderScheduleType.oneTime] reminder fires (or the start
  /// of a bounded schedule).
  final DateTime? startDate;

  /// Optional last date a repeating reminder should fire.
  final DateTime? endDate;

  /// Day of month (1..31) used by [ReminderScheduleType.monthly].
  final int? monthDay;

  /// Material icon key used for the notification small icon.
  final String? icon;

  /// ARGB value used for the notification accent colour.
  final int? colorValue;

  final bool soundEnabled;
  final bool vibrationEnabled;

  /// Silent mode overrides sound + vibration for this reminder.
  final bool silentMode;

  /// Whether the notification shows Complete / Skip action buttons.
  final bool showActionButtons;

  /// Route path opened when the notification is tapped.
  final String? relatedScreen;

  final bool isEnabled;
  final DateTime? lastTriggeredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Every configured "HH:mm" time, primary first.
  List<String> get allTimes {
    final List<String> unique = <String>[];
    for (final String t in <String>[time, ...times]) {
      if (!unique.contains(t)) unique.add(t);
    }
    return unique;
  }

  /// True when [other] would be an identical reminder (used to reject
  /// duplicate reminders before persisting).
  bool isDuplicateOf(Reminder other) {
    if (other.reminderType != reminderType) return false;
    if (other.scheduleType != scheduleType) return false;
    if (other.title.trim().toLowerCase() != title.trim().toLowerCase()) {
      return false;
    }
    final Set<String> mine = allTimes.toSet();
    final Set<String> theirs = other.allTimes.toSet();
    if (mine.length != theirs.length || !mine.containsAll(theirs)) return false;
    if (other.daysOfWeek.length != daysOfWeek.length) return false;
    if (!daysOfWeek.toSet().containsAll(other.daysOfWeek)) return false;
    if (other.startDate != startDate) return false;
    if (other.monthDay != monthDay) return false;
    return true;
  }

  Reminder copyWith({
    int? id,
    String? userId,
    String? title,
    String? body,
    ReminderType? reminderType,
    String? time,
    List<int>? daysOfWeek,
    ReminderScheduleType? scheduleType,
    List<String>? times,
    DateTime? startDate,
    DateTime? endDate,
    int? monthDay,
    String? icon,
    int? colorValue,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? silentMode,
    bool? showActionButtons,
    String? relatedScreen,
    bool? isEnabled,
    DateTime? lastTriggeredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      reminderType: reminderType ?? this.reminderType,
      time: time ?? this.time,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      scheduleType: scheduleType ?? this.scheduleType,
      times: times ?? this.times,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      monthDay: monthDay ?? this.monthDay,
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      silentMode: silentMode ?? this.silentMode,
      showActionButtons: showActionButtons ?? this.showActionButtons,
      relatedScreen: relatedScreen ?? this.relatedScreen,
      isEnabled: isEnabled ?? this.isEnabled,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        body,
        reminderType,
        time,
        daysOfWeek,
        scheduleType,
        times,
        startDate,
        endDate,
        monthDay,
        icon,
        colorValue,
        soundEnabled,
        vibrationEnabled,
        silentMode,
        showActionButtons,
        relatedScreen,
        isEnabled,
        lastTriggeredAt,
        createdAt,
        updatedAt,
      ];
}
