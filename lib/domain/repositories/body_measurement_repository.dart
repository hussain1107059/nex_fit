import '../entities/body_measurement.dart';

/// Contract for the user's body circumference measurements.
abstract interface class BodyMeasurementRepository {
  Future<int> insert(BodyMeasurement measurement);

  Future<void> update(BodyMeasurement measurement);

  Future<BodyMeasurement?> getById(int id);

  Future<List<BodyMeasurement>> getByUserId(String userId);

  Future<List<BodyMeasurement>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  );

  Future<BodyMeasurement?> getLatest(String userId);

  Future<void> delete(int id);
}
