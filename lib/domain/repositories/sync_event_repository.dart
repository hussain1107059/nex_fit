import 'package:sqflite/sqflite.dart' show Transaction;

import '../entities/security_enums.dart';
import '../entities/sync_event.dart';

/// Contract for the offline sync event queue (outbox).
abstract interface class SyncEventRepository {
  Future<int> insert(SyncEvent event);

  /// Inserts [event] inside an existing transaction (atomic mutation+outbox).
  Future<void> insertInTransaction(Transaction txn, SyncEvent event);

  Future<void> update(SyncEvent event);

  /// Batches a set of event updates (e.g. acknowledging a queue run) into a
  /// single transaction.
  Future<void> updateAll(List<SyncEvent> events);

  Future<List<SyncEvent>> getPendingByUserId(
    String userId, {
    int? limit,
    int? offset,
  });

  /// Every event for [userId] that has not reached a final state
  /// (pending, retryable, processing or permanently failed), oldest first.
  /// Used by developer diagnostics to surface stuck outbox events and their
  /// `last_error` without touching the queue.
  Future<List<SyncEvent>> getNonCompletedByUserId(
    String userId, {
    int limit = 100,
  });

  /// Developer recovery: re-queues every non-final event for [userId] back to
  /// PENDING with a zeroed retry counter so the next sync run retries them.
  Future<void> requeueAllByUserId(String userId, {required DateTime at});

  /// Events eligible to run right now: pending or retryable whose
  /// `next_retry_at` has passed.
  Future<List<SyncEvent>> getRetryableByUserId(
    String userId, {
    int? limit,
    int? offset,
    DateTime? now,
  });

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

  /// Marks an event as in-flight (see outbox protocol).
  Future<void> markProcessing(int id, {required DateTime at});

  /// Marks an event as delivered.
  Future<void> markSuccess(
    int id, {
    required DateTime at,
    required DateTime syncedAt,
  });

  /// Marks an event as a transient failure eligible for retry after
  /// [nextRetryAt].
  Future<void> markRetryableFailure(
    int id, {
    required String lastError,
    required int retryCount,
    required DateTime at,
    required DateTime nextRetryAt,
  });

  /// Marks an event as a terminal failure.
  Future<void> markPermanentFailure(
    int id, {
    required String lastError,
    required int retryCount,
    required DateTime at,
  });

  /// Reclaims PROCESSING events stuck longer than [olderThan] back to PENDING.
  Future<List<int>> resetStuckProcessingEvents(
    String userId, {
    required DateTime olderThan,
    required DateTime at,
  });

  Future<int> getPendingCount(String userId);

  Future<int> getFailedCount(String userId);
}
