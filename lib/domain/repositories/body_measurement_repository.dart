import '../entities/body_measurement.dart';

/// Contract for the user's body circumference measurements.
abstract interface class BodyMeasurementRepository {
  Future<int> insert(BodyMeasurement measurement);

  Future<void> update(BodyMeasurement measurement);

  Future<BodyMeasurement?> getById(int id);

  Future<List<BodyMeasurement>> getByUserId(String userId);

  Future<void> delete(int id);
}
