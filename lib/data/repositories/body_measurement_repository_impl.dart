import '../../domain/entities/body_measurement.dart';
import '../../domain/repositories/body_measurement_repository.dart';
import '../datasources/local/body_measurement_local_data_source.dart';

/// SQLite backed implementation of [BodyMeasurementRepository].
class BodyMeasurementRepositoryImpl implements BodyMeasurementRepository {
  const BodyMeasurementRepositoryImpl(this._dataSource);

  final BodyMeasurementLocalDataSource _dataSource;

  @override
  Future<int> insert(BodyMeasurement measurement) =>
      _dataSource.insert(measurement);

  @override
  Future<void> update(BodyMeasurement measurement) =>
      _dataSource.update(measurement);

  @override
  Future<BodyMeasurement?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<BodyMeasurement>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<List<BodyMeasurement>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) => _dataSource.getByDateRange(userId, start, end);

  @override
  Future<BodyMeasurement?> getLatest(String userId) =>
      _dataSource.getLatest(userId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
