import '../../domain/entities/app_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../datasources/local/session_local_data_source.dart';

/// SQLite backed implementation of [SessionRepository].
class SessionRepositoryImpl implements SessionRepository {
  const SessionRepositoryImpl(this._dataSource);

  final SessionLocalDataSource _dataSource;

  @override
  Future<int> insert(AppSession session) => _dataSource.insert(session);

  @override
  Future<void> update(AppSession session) => _dataSource.update(session);

  @override
  Future<AppSession?> getActiveByUserId(String userId) =>
      _dataSource.getActiveByUserId(userId);

  @override
  Future<List<AppSession>> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<void> deactivateByUserId(String userId) =>
      _dataSource.deactivateByUserId(userId);

  @override
  Future<void> deleteInactiveOlderThan(DateTime threshold) =>
      _dataSource.deleteOlderThan(threshold);
}
