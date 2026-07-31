import '../entities/bmi_log.dart';

/// Contract for the user's BMI history.
abstract interface class BmiLogRepository {
  Future<int> insert(BmiLog log);

  Future<BmiLog?> getById(int id);

  Future<List<BmiLog>> getByUserId(String userId);

  Future<void> delete(int id);
}
