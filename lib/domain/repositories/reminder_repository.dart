import '../entities/reminder.dart';

/// Contract for managing the user's reminders.
abstract interface class ReminderRepository {
  Future<int> insert(Reminder reminder);

  Future<void> update(Reminder reminder);

  Future<Reminder?> getById(int id);

  Future<List<Reminder>> getByUserId(String userId);

  Future<List<Reminder>> getEnabled(String userId);

  Future<void> delete(int id);
}
