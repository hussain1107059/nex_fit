/// Shared calendar helpers used by the repository layer.
library;

/// Normalizes [date] to the start of its calendar day (midnight).
DateTime dayStart(DateTime date) => DateTime(date.year, date.month, date.day);

/// Returns the [DateTime] for Monday of [date]'s week (weeks start Monday).
DateTime weekStart(DateTime date) {
  final DateTime day = dayStart(date);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// Counts consecutive days ending at [now] present in [days] (a set of
/// day-starts). If today is missing, the streak is measured from yesterday.
int currentStreak(Set<DateTime> days, DateTime now) {
  if (days.isEmpty) return 0;
  DateTime cursor = dayStart(now);
  if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
  int streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Length of the longest run of consecutive days in sorted [days].
int longestStreak(List<DateTime> days) {
  if (days.isEmpty) return 0;
  int longest = 1;
  int run = 1;
  for (int i = 1; i < days.length; i++) {
    if (days[i].difference(days[i - 1]).inDays == 1) {
      run++;
    } else {
      run = 1;
    }
    if (run > longest) longest = run;
  }
  return longest;
}

/// Trims [note]; returns `null` for a blank value so optional notes are stored
/// as NULL instead of an empty string.
String? cleanNote(String? note) {
  if (note == null) return null;
  final String trimmed = note.trim();
  return trimmed.isEmpty ? null : trimmed;
}
