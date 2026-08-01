import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/string_extensions.dart';
import '../../../domain/entities/common_enums.dart';
import '../../../domain/entities/reminder.dart';
import '../../../l10n/app_localizations.dart';
import '../../../presentation/providers/reminder_providers.dart';
import '../../../data/services/notifications/reminder_schedule.dart';

/// Icon for a reminder type.
IconData reminderTypeIcon(ReminderType type) {
  return switch (type) {
    ReminderType.workout => Icons.fitness_center_rounded,
    ReminderType.water => Icons.water_drop_rounded,
    ReminderType.meal => Icons.restaurant_rounded,
    ReminderType.weight => Icons.monitor_weight_rounded,
    ReminderType.sleep => Icons.bedtime_rounded,
    ReminderType.medicine => Icons.medication_rounded,
    ReminderType.step => Icons.directions_walk_rounded,
    ReminderType.custom => Icons.notifications_active_rounded,
  };
}

/// Accent colour for a reminder type.
Color reminderTypeColor(ReminderType type) {
  return Color(defaultColorFor(type));
}

/// Localised label for a reminder type.
String reminderTypeLabel(AppLocalizations l10n, ReminderType type) {
  return switch (type) {
    ReminderType.workout => l10n.reminderTypeWorkout,
    ReminderType.water => l10n.reminderTypeWater,
    ReminderType.meal => l10n.reminderTypeMeal,
    ReminderType.weight => l10n.reminderTypeWeight,
    ReminderType.sleep => l10n.reminderTypeSleep,
    ReminderType.medicine => l10n.reminderTypeMedicine,
    ReminderType.step => l10n.reminderTypeStep,
    ReminderType.custom => l10n.reminderTypeCustom,
  };
}

/// Localised label for a schedule type.
String scheduleTypeLabel(AppLocalizations l10n, ReminderScheduleType type) {
  return switch (type) {
    ReminderScheduleType.oneTime => l10n.reminderScheduleOneTime,
    ReminderScheduleType.daily => l10n.reminderScheduleDaily,
    ReminderScheduleType.weekly => l10n.reminderScheduleWeekly,
    ReminderScheduleType.monthly => l10n.reminderScheduleMonthly,
    ReminderScheduleType.customDays => l10n.reminderScheduleCustomDays,
  };
}

/// Human readable summary of a reminder's schedule.
String reminderScheduleSummary(
  AppLocalizations l10n,
  Reminder reminder, {
  ReminderTimeFormat timeFormat = ReminderTimeFormat.h12,
}) {
  final String times = reminder.allTimes
      .map((String t) => formatReminderTime(t, timeFormat))
      .join(', ');

  switch (reminder.scheduleType) {
    case ReminderScheduleType.oneTime:
      if (reminder.startDate == null) {
        return '${l10n.reminderScheduleOneTime} · $times';
      }
      final String date = DateFormat('dd MMM yyyy').format(reminder.startDate!);
      return '$date · $times';
    case ReminderScheduleType.daily:
      return '${l10n.reminderScheduleDaily} · $times';
    case ReminderScheduleType.weekly:
      return '${l10n.reminderScheduleWeekly} · ${_weekdaySummary(l10n, reminder.daysOfWeek)} · $times';
    case ReminderScheduleType.monthly:
      final int? day = reminder.monthDay;
      final String dayLabel = day == null
          ? l10n.reminderEveryMonth
          : l10n.reminderDayOfMonth('$day');
      return '$dayLabel · $times';
    case ReminderScheduleType.customDays:
      final String days = reminder.daysOfWeek.isEmpty
          ? l10n.reminderEveryDay
          : _weekdaySummary(l10n, reminder.daysOfWeek);
      return '$days · $times';
  }
}

String _weekdaySummary(AppLocalizations l10n, List<int> days) {
  const List<String> names = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  if (days.length == 7) return l10n.reminderEveryDay;
  final List<String> ordered = <int>[1, 2, 3, 4, 5, 6, 7]
      .where(days.contains)
      .map((int day) => names[day - 1])
      .toList();
  return ordered.join(', ');
}

/// Formats a "HH:mm" string in the user's preferred 12/24h format.
String formatReminderTime(String hhmm, ReminderTimeFormat timeFormat) {
  final (int hour, int minute) = parseHhmm(hhmm);
  if (timeFormat == ReminderTimeFormat.h24) {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
  return DateFormat('h:mm a')
      .format(DateTime(0, 1, 1, hour, minute))
      .toBanglaDigits();
}
