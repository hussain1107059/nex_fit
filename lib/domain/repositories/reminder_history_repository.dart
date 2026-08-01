import '../entities/common_enums.dart';
import '../entities/reminder_history.dart';
import '../entities/reminder_statistics.dart';

/// Contract for recording and querying reminder occurrences.
abstract interface class ReminderHistoryRepository {
  Future<int> insert(ReminderHistory history);

  /// Inserts many occurrences in a single transaction.
  Future<void> insertAll(List<ReminderHistory> history);

  Future<void> update(ReminderHistory history);

  Future<List<ReminderHistory>> getByUserId(String userId);

  Future<List<ReminderHistory>> getByReminderId(int reminderId);

  Future<List<ReminderHistory>> getByStatus(
    String userId,
    ReminderHistoryStatus status,
  );

  /// Datetimes already recorded for [reminderId].
  Future<List<DateTime>> getScheduledFor(int reminderId);

  /// Removes every occurrence belonging to [reminderId].
  Future<void> deleteByReminderId(int reminderId);

  /// Records missed occurrences for every enabled reminder between the last
  /// sync point and [now]. Returns the number of new rows.
  Future<int> syncMissed(String userId, DateTime now);

  Future<ReminderStatistics> getStatistics(String userId);
}
