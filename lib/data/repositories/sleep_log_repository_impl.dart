import '../../domain/entities/sleep_log.dart';
import '../../domain/repositories/sleep_log_repository.dart';
import '../datasources/local/sleep_log_local_data_source.dart';

/// SQLite backed implementation of [SleepLogRepository].
class SleepLogRepositoryImpl implements SleepLogRepository {
  const SleepLogRepositoryImpl(this._dataSource);

  final SleepLogLocalDataSource _dataSource;

  @override
  Future<int> insert(SleepLog log) => _dataSource.insert(log);

  @override
  Future<void> update(SleepLog log) => _dataSource.update(log);

  @override
  Future<SleepLog?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<SleepLog>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<SleepLog?> getByDate(String userId, DateTime sleepDate) =>
      _dataSource.getByDate(userId, sleepDate);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
