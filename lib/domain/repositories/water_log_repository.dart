import '../entities/water_log.dart';

/// Contract for the user's water intake log.
abstract interface class WaterLogRepository {
  Future<int> insert(WaterLog log);

  Future<void> update(WaterLog log);

  Future<WaterLog?> getById(int id);

  Future<List<WaterLog>> getByUserId(String userId);

  Future<List<WaterLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  );

  Future<void> delete(int id);
}
