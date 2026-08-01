import '../../../domain/entities/common_enums.dart';
import '../../../domain/entities/reminder.dart';

/// Parses a "HH:mm" 24h string into clamped (hour, minute).
(int, int) parseHhmm(String value) {
  final List<String> parts = value.split(':');
  final int hour = int.tryParse(parts.isEmpty ? '' : parts[0]) ?? 0;
  final int minute = parts.length < 2 ? 0 : (int.tryParse(parts[1]) ?? 0);
  return (hour.clamp(0, 23), minute.clamp(0, 59));
}

/// Formats (hour, minute) as a "HH:mm" 24h string.
String formatHhmm(int hour, int minute) {
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

DateTime _dayStart(DateTime date) => DateTime(date.year, date.month, date.day);

/// All scheduled datetimes of [reminder] that fall inside
/// [start] (inclusive) .. [end] (inclusive), sorted ascending.
///
/// Occurrences past [Reminder.endDate] are never returned. One-time reminders
/// only return their single [Reminder.startDate] occurrence.
List<DateTime> reminderOccurrences(
  Reminder reminder,
  DateTime start,
  DateTime end,
) {
  if (!reminder.isEnabled) return const <DateTime>[];
  final DateTime from = _dayStart(start);
  final DateTime to = _dayStart(end);
  final DateTime firstDay =
      reminder.startDate != null ? _dayStart(reminder.startDate!) : from;
  final DateTime effectiveFrom = firstDay.isAfter(from) ? firstDay : from;
  if (effectiveFrom.isAfter(to)) return const <DateTime>[];

  final List<DateTime> occurrences = <DateTime>[];
  for (final String time in reminder.allTimes) {
    final (int hour, int minute) = parseHhmm(time);
    switch (reminder.scheduleType) {
      case ReminderScheduleType.oneTime:
        final DateTime? when = reminder.startDate;
        if (when == null) continue;
        final DateTime candidate = DateTime(
          when.year,
          when.month,
          when.day,
          hour,
          minute,
        );
        if (!candidate.isBefore(start) &&
            !candidate.isAfter(end) &&
            !_beyondEnd(reminder, candidate)) {
          occurrences.add(candidate);
        }
      case ReminderScheduleType.daily:
        DateTime cursor = effectiveFrom;
        while (!cursor.isAfter(to)) {
          final DateTime candidate = DateTime(
            cursor.year,
            cursor.month,
            cursor.day,
            hour,
            minute,
          );
          if (!candidate.isBefore(start) &&
              !candidate.isAfter(end) &&
              !_beyondEnd(reminder, candidate)) {
            occurrences.add(candidate);
          }
          cursor = cursor.add(const Duration(days: 1));
        }
      case ReminderScheduleType.weekly:
        for (final int day in reminder.daysOfWeek) {
          _forMatchingWeekdays(
            reminder,
            effectiveFrom,
            to,
            start,
            end,
            hour,
            minute,
            (int weekday) => weekday == day,
            occurrences,
          );
        }
      case ReminderScheduleType.customDays:
        final Set<int> selected = reminder.daysOfWeek.toSet();
        _forMatchingWeekdays(
          reminder,
          effectiveFrom,
          to,
          start,
          end,
          hour,
          minute,
          selected.contains,
          occurrences,
        );
      case ReminderScheduleType.monthly:
        final int? dayOfMonth = reminder.monthDay;
        if (dayOfMonth == null || dayOfMonth < 1) continue;
        DateTime cursor = DateTime(effectiveFrom.year, effectiveFrom.month, 1);
        final DateTime lastMonth = DateTime(to.year, to.month, 1);
        while (!cursor.isAfter(lastMonth)) {
          final int daysInMonth = DateTime(cursor.year, cursor.month + 1, 0).day;
          if (dayOfMonth <= daysInMonth) {
            final DateTime candidate = DateTime(
              cursor.year,
              cursor.month,
              dayOfMonth,
              hour,
              minute,
            );
            if (!candidate.isBefore(start) &&
                !candidate.isAfter(end) &&
                !_beyondEnd(reminder, candidate)) {
              occurrences.add(candidate);
            }
          }
          cursor = DateTime(cursor.year, cursor.month + 1, 1);
        }
    }
  }

  occurrences.sort();
  return occurrences;
}

void _forMatchingWeekdays(
  Reminder reminder,
  DateTime from,
  DateTime to,
  DateTime start,
  DateTime end,
  int hour,
  int minute,
  bool Function(int weekday) matches,
  List<DateTime> occurrences,
) {
  DateTime cursor = from;
  while (!cursor.isAfter(to)) {
    if (matches(cursor.weekday)) {
      final DateTime candidate = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        hour,
        minute,
      );
      if (!candidate.isBefore(start) &&
          !candidate.isAfter(end) &&
          !_beyondEnd(reminder, candidate)) {
        occurrences.add(candidate);
      }
    }
    cursor = cursor.add(const Duration(days: 1));
  }
}

bool _beyondEnd(Reminder reminder, DateTime candidate) {
  final DateTime? endDate = reminder.endDate;
  if (endDate == null) return false;
  final DateTime day = _dayStart(candidate);
  return day.isAfter(_dayStart(endDate));
}

/// The next occurrence strictly after [after], or null when the reminder is
/// disabled, already finished, or never fires again.
DateTime? nextReminderOccurrence(Reminder reminder, DateTime after) {
  final DateTime horizon = after.add(const Duration(days: 730));
  final List<DateTime> occurrences = reminderOccurrences(
    reminder,
    after,
    horizon,
  );
  for (final DateTime candidate in occurrences) {
    if (candidate.isAfter(after)) return candidate;
  }
  return null;
}
