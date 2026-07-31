import '../../domain/entities/calorie_log.dart';
import '../../domain/repositories/calorie_log_repository.dart';
import '../datasources/local/calorie_log_local_data_source.dart';

/// SQLite backed implementation of [CalorieLogRepository].
class CalorieLogRepositoryImpl implements CalorieLogRepository {
  const CalorieLogRepositoryImpl(this._dataSource);

  final CalorieLogLocalDataSource _dataSource;

  @override
  Future<int> insert(CalorieLog log) => _dataSource.insert(log);

  @override
  Future<void> update(CalorieLog log) => _dataSource.update(log);

  @override
  Future<CalorieLog?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<CalorieLog>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<List<CalorieLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) => _dataSource.getByDateRange(userId, start, end);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
