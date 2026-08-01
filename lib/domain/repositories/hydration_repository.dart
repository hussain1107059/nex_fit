import '../entities/daily_hydration.dart';
import '../entities/reminder.dart';
import '../entities/water_history.dart';
import '../entities/water_log.dart';
import '../entities/water_statistics.dart';

/// Contract for the complete water tracker & hydration module.
///
/// Aggregates the water log, the daily goal (stored on the user profile) and
/// the hydration reminders into the domain payloads consumed by the UI, and
/// keeps the scheduled local notifications in sync with the reminder table.
abstract interface class HydrationRepository {
  /// Aggregates a single calendar day's intake against the daily goal.
  Future<DailyHydration> loadDaily(String userId, DateTime date);

  /// Bucketed intake history across [period].
  Future<WaterHistory> loadHistory(
    String userId,
    WaterHistoryPeriod period,
  );

  /// Lifetime statistics (averages, best day, streaks, totals).
  Future<WaterStatistics> loadStatistics(String userId);

  /// The user's daily hydration goal in ml (defaults to 2000).
  Future<int> getGoal(String userId);

  /// Persists a new daily hydration goal.
  Future<void> setGoal(String userId, int goalMl);

  /// Logs a water entry and returns its database id.
  Future<int> addEntry(
    String userId,
    int amountMl, {
    DateTime? date,
    String? note,
  });

  /// Edits an existing water entry.
  Future<void> updateEntry(WaterLog log);

  /// Deletes a water entry.
  Future<void> deleteEntry(int id);

  /// All reminders for the user (used to keep the UI in sync).
  Future<List<Reminder>> getReminders(String userId);

  /// Creates a reminder and schedules its local notifications.
  Future<int> addReminder(Reminder reminder);

  /// Updates a reminder and reschedules its local notifications.
  Future<void> updateReminder(Reminder reminder);

  /// Deletes a reminder and cancels its local notifications.
  Future<void> deleteReminder(int id);

  /// Re-syncs scheduled notifications with the enabled reminders of [userId].
  /// Called on app start so reminders survive reboots and re-installs.
  Future<void> rescheduleAll(String userId);
}
