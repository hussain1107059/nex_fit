import '../../domain/entities/bmi_log.dart';
import '../../domain/repositories/bmi_log_repository.dart';
import '../datasources/local/bmi_log_local_data_source.dart';

/// SQLite backed implementation of [BmiLogRepository].
class BmiLogRepositoryImpl implements BmiLogRepository {
  const BmiLogRepositoryImpl(this._dataSource);

  final BmiLogLocalDataSource _dataSource;

  @override
  Future<int> insert(BmiLog log) => _dataSource.insert(log);

  @override
  Future<BmiLog?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<BmiLog>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
