import '../../domain/entities/water_log.dart';
import '../../domain/repositories/water_log_repository.dart';
import '../datasources/local/water_log_local_data_source.dart';

/// SQLite backed implementation of [WaterLogRepository].
class WaterLogRepositoryImpl implements WaterLogRepository {
  const WaterLogRepositoryImpl(this._dataSource);

  final WaterLogLocalDataSource _dataSource;

  @override
  Future<int> insert(WaterLog log) => _dataSource.insert(log);

  @override
  Future<void> update(WaterLog log) => _dataSource.update(log);

  @override
  Future<WaterLog?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<WaterLog>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<List<WaterLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) => _dataSource.getByDateRange(userId, start, end);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
