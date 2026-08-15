import '../entities/sleep_log.dart';

/// Contract for the user's sleep log.
abstract interface class SleepLogRepository {
  Future<int> insert(SleepLog log);

  Future<void> update(SleepLog log);

  Future<SleepLog?> getById(int id);

  Future<List<SleepLog>> getByUserId(String userId);

  Future<SleepLog?> getByDate(String userId, DateTime sleepDate);

  Future<List<SleepLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  );

  Future<void> delete(int id);
}
