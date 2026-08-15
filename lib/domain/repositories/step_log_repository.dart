import '../entities/step_log.dart';

/// Contract for the user's step log.
abstract interface class StepLogRepository {
  Future<int> insert(StepLog log);

  Future<void> update(StepLog log);

  Future<StepLog?> getById(int id);

  Future<List<StepLog>> getByUserId(String userId);

  Future<StepLog?> getByDate(String userId, DateTime stepDate);

  Future<List<StepLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  );

  Future<void> delete(int id);
}
