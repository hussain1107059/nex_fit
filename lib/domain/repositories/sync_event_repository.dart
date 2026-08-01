import '../entities/security_enums.dart';
import '../entities/sync_event.dart';

/// Contract for the offline sync event queue.
abstract interface class SyncEventRepository {
  Future<int> insert(SyncEvent event);

  Future<void> update(SyncEvent event);

  Future<List<SyncEvent>> getPendingByUserId(String userId);

  Future<SyncEvent?> findDuplicate(
    String userId,
    String entity,
    String entityId,
    SyncOperation operation,
  );

  Future<Map<String, int>> countByStatus(String userId);

  Future<DateTime?> latestSyncedAt(String userId);

  Future<void> deleteCompletedOlderThan(String userId, DateTime threshold);

  Future<void> deleteCompletedOlderThanAll(DateTime threshold);
}
