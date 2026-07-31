import '../entities/calorie_log.dart';

/// Contract for the user's calorie summaries.
abstract interface class CalorieLogRepository {
  Future<int> insert(CalorieLog log);

  Future<void> update(CalorieLog log);

  Future<CalorieLog?> getById(int id);

  Future<List<CalorieLog>> getByUserId(String userId);

  Future<List<CalorieLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  );

  Future<void> delete(int id);
}
