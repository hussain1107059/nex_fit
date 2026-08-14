import '../../domain/entities/sync_conflict_record.dart';
import '../../domain/repositories/sync_conflict_repository.dart';
import '../datasources/local/sync_conflict_local_data_source.dart';

/// Repository implementation backed by the local conflict table (PROMPT 19).
class SyncConflictRepositoryImpl implements SyncConflictRepository {
  SyncConflictRepositoryImpl(this._dataSource);

  final SyncConflictLocalDataSource _dataSource;

  @override
  Future<void> record(SyncConflictRecord record) =>
      _dataSource.record(record);

  @override
  Future<List<SyncConflictRecord>> getPending(String userId) =>
      _dataSource.getPending(userId);

  @override
  Future<List<SyncConflictRecord>> getHistory(
    String userId, {
    int limit = 50,
  }) =>
      _dataSource.getHistory(userId, limit: limit);

  @override
  Future<int> countPending(String userId) =>
      _dataSource.countPending(userId);

  @override
  Future<void> markResolved(int id, {required DateTime at}) =>
      _dataSource.markResolved(id, at: at);
}