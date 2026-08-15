import '../../domain/entities/step_log.dart';
import '../../domain/repositories/step_log_repository.dart';
import '../datasources/local/step_log_local_data_source.dart';

/// SQLite backed implementation of [StepLogRepository].
class StepLogRepositoryImpl implements StepLogRepository {
  const StepLogRepositoryImpl(this._dataSource);

  final StepLogLocalDataSource _dataSource;

  @override
  Future<int> insert(StepLog log) => _dataSource.insert(log);

  @override
  Future<void> update(StepLog log) => _dataSource.update(log);

  @override
  Future<StepLog?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<StepLog>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<StepLog?> getByDate(String userId, DateTime stepDate) =>
      _dataSource.getByDate(userId, stepDate);

  @override
  Future<List<StepLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) => _dataSource.getByDateRange(userId, start, end);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
