import '../../domain/entities/activity.dart';
import '../../domain/repositories/activity_repository.dart';
import '../datasources/local/activity_local_data_source.dart';

/// SQLite backed implementation of [ActivityRepository].
class ActivityRepositoryImpl implements ActivityRepository {
  const ActivityRepositoryImpl(this._dataSource);

  final ActivityLocalDataSource _dataSource;

  @override
  Future<int> insert(ActivitySession session) => _dataSource.insert(session);

  @override
  Future<void> update(ActivitySession session) => _dataSource.update(session);

  @override
  Future<ActivitySession?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<ActivitySession>> getByUserId(String userId, {int limit = 50}) =>
      _dataSource.getByUserId(userId, limit: limit);

  @override
  Future<ActivityStats> getStats(String userId) => _dataSource.getStats(userId);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);
}
