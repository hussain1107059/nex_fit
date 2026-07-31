import '../entities/weight_log.dart';

/// Contract for the user's body weight log.
abstract interface class WeightLogRepository {
  Future<int> insert(WeightLog log);

  Future<void> update(WeightLog log);

  Future<WeightLog?> getById(int id);

  Future<List<WeightLog>> getByUserId(String userId);

  Future<List<WeightLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  );

  Future<WeightLog?> getLatest(String userId);

  Future<void> delete(int id);
}
