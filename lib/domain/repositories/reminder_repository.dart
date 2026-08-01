import '../entities/reminder.dart';

/// Contract for managing the user's reminders.
abstract interface class ReminderRepository {
  Future<int> insert(Reminder reminder);

  Future<void> update(Reminder reminder);

  Future<Reminder?> getById(int id);

  Future<List<Reminder>> getByUserId(String userId);

  Future<List<Reminder>> getEnabled(String userId);

  Future<void> delete(int id);

  /// Creates a deep copy of [id] (new row, same schedule) and schedules its
  /// notifications. Returns the new reminder id.
  Future<int> duplicate(int id);

  /// True when a reminder identical to [candidate] already exists.
  Future<bool> hasDuplicate(Reminder candidate);

  /// True when an enabled reminder exists whose [isDuplicateOf] matches.
  Future<Reminder?> findDuplicate(Reminder candidate);
}
