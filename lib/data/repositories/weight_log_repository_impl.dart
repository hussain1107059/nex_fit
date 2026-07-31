import '../../domain/entities/weight_log.dart';
import '../../domain/repositories/weight_log_repository.dart';
import '../datasources/local/weight_log_local_data_source.dart';

/// SQLite backed implementation of [WeightLogRepository].
class WeightLogRepositoryImpl implements WeightLogRepository {
  const WeightLogRepositoryImpl(this._dataSource);

  final WeightLogLocalDataSource _dataSource;

  @override
  Future<int> insert(WeightLog log) => _dataSource.insert(log);

  @override
  Future<void> update(WeightLog log) => _dataSource.update(log);

  @override
  Future<WeightLog?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<WeightLog>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<List<WeightLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) => _dataSource.getByDateRange(userId, start, end);

  @override
  Future<WeightLog?> getLatest(String userId) => _dataSource.getLatest(userId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
