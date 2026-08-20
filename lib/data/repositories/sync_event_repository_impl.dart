import 'package:sqflite/sqflite.dart' show Transaction;

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
  Future<void> insertInTransaction(Transaction txn, SyncEvent event) =>
      _dataSource.insertInTransaction(txn, event);

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
  Future<List<SyncEvent>> getNonCompletedByUserId(
    String userId, {
    int limit = 100,
  }) => _dataSource.getNonCompletedByUserId(userId, limit: limit);

  @override
  Future<void> requeueAllByUserId(String userId, {required DateTime at}) =>
      _dataSource.requeueAllByUserId(userId, at: at);

  @override
  Future<void> resolvePermanentFailures(
    String userId, {
    required DateTime at,
  }) => _dataSource.resolvePermanentFailures(userId, at: at);

  @override
  Future<List<SyncEvent>> getRetryableByUserId(
    String userId, {
    int? limit,
    int? offset,
    DateTime? now,
  }) => _dataSource.getRetryableByUserId(
    userId,
    limit: limit,
    offset: offset,
    now: now,
  );

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

  @override
  Future<void> markProcessing(int id, {required DateTime at}) =>
      _dataSource.markProcessing(id, at: at);

  @override
  Future<void> markSuccess(
    int id, {
    required DateTime at,
    required DateTime syncedAt,
  }) => _dataSource.markSuccess(id, at: at, syncedAt: syncedAt);

  @override
  Future<void> markRetryableFailure(
    int id, {
    required String lastError,
    required int retryCount,
    required DateTime at,
    required DateTime nextRetryAt,
  }) => _dataSource.markRetryableFailure(
    id,
    lastError: lastError,
    retryCount: retryCount,
    at: at,
    nextRetryAt: nextRetryAt,
  );

  @override
  Future<void> markPermanentFailure(
    int id, {
    required String lastError,
    required int retryCount,
    required DateTime at,
  }) => _dataSource.markPermanentFailure(
    id,
    lastError: lastError,
    retryCount: retryCount,
    at: at,
  );

  @override
  Future<List<int>> resetStuckProcessingEvents(
    String userId, {
    required DateTime olderThan,
    required DateTime at,
  }) => _dataSource.resetStuckProcessingEvents(
    userId,
    olderThan: olderThan,
    at: at,
  );

  @override
  Future<int> getPendingCount(String userId) =>
      _dataSource.getPendingCount(userId);

  @override
  Future<int> getFailedCount(String userId) =>
      _dataSource.getFailedCount(userId);
}
