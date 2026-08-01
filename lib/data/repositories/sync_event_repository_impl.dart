import '../../domain/entities/security_enums.dart';
import '../../domain/entities/sync_event.dart';
import '../../domain/repositories/sync_event_repository.dart';
import '../datasources/local/sync_event_local_data_source.dart';

/// SQLite backed implementation of [SyncEventRepository].
class SyncEventRepositoryImpl implements SyncEventRepository {
  const SyncEventRepositoryImpl(this._dataSource);

  final SyncEventLocalDataSource _dataSource;

  @override
  Future<int> insert(SyncEvent event) => _dataSource.insert(event);

  @override
  Future<void> update(SyncEvent event) => _dataSource.update(event);

  @override
  Future<void> updateAll(List<SyncEvent> events) => _dataSource.updateAll(events);

  @override
  Future<List<SyncEvent>> getPendingByUserId(
    String userId, {
    int? limit,
    int? offset,
  }) => _dataSource.getPendingByUserId(userId, limit: limit, offset: offset);

  @override
  Future<SyncEvent?> findDuplicate(
    String userId,
    String entity,
    String entityId,
    SyncOperation operation,
  ) => _dataSource.findDuplicate(userId, entity, entityId, operation);

  @override
  Future<Map<String, int>> countByStatus(String userId) =>
      _dataSource.countByStatus(userId);

  @override
  Future<DateTime?> latestSyncedAt(String userId) =>
      _dataSource.latestSyncedAt(userId);

  @override
  Future<void> deleteCompletedOlderThan(String userId, DateTime threshold) =>
      _dataSource.deleteCompletedOlderThan(userId, threshold);

  @override
  Future<void> deleteCompletedOlderThanAll(DateTime threshold) =>
      _dataSource.deleteCompletedOlderThanAll(threshold);
}
