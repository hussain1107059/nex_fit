import '../entities/sync_conflict_record.dart';

/// Contract for the durable conflict store (PROMPT 19).
abstract interface class SyncConflictRepository {
  /// Persists a conflict. A pending record for the same
  /// (user, entity, record uuid) is updated in place (repeated conflicts on an
  /// unresolved record refresh the server snapshot); resolved records append as
  /// history.
  Future<void> record(SyncConflictRecord record);

  Future<List<SyncConflictRecord>> getPending(String userId);

  Future<List<SyncConflictRecord>> getHistory(
    String userId, {
    int limit = 50,
  });

  Future<int> countPending(String userId);

  /// Marks a pending conflict as manually resolved.
  Future<void> markResolved(
    int id, {
    required DateTime at,
  });
}