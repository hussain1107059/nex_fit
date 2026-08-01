import '../../domain/entities/error_log.dart';
import '../../domain/repositories/error_log_repository.dart';
import '../datasources/local/error_log_local_data_source.dart';

/// SQLite backed implementation of [ErrorLogRepository].
class ErrorLogRepositoryImpl implements ErrorLogRepository {
  const ErrorLogRepositoryImpl(this._dataSource);

  final ErrorLogLocalDataSource _dataSource;

  @override
  Future<int> insert(ErrorLog log) => _dataSource.insert(log);

  @override
  Future<List<ErrorLog>> getRecent({String? userId, int limit = 50}) =>
      _dataSource.getRecent(userId: userId, limit: limit);

  @override
  Future<int> count({String? userId}) => _dataSource.count(userId: userId);

  @override
  Future<void> deleteOlderThan(DateTime threshold) =>
      _dataSource.deleteOlderThan(threshold);
}
