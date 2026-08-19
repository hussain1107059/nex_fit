import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/security_enums.dart';
import '../../../domain/entities/sync_event.dart';
import '../../models/sync_event_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `sync_event` table (the offline sync queue).
class SyncEventLocalDataSource extends BaseLocalDataSource {
  SyncEventLocalDataSource({required super.database})
    : super(logName: 'SyncEventLocalDataSource');

  Future<int> insert(SyncEvent event) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(SyncEventModel.table, SyncEventModel.toMap(event));
    });
  }

  /// Inserts [event] inside an existing [Transaction] so the local mutation
  /// and its outbox entry commit atomically (Part 5 of the sync foundation).
  Future<void> insertInTransaction(Transaction txn, SyncEvent event) {
    return guard('insert_in_transaction', () async {
      await txn.insert(SyncEventModel.table, SyncEventModel.toMap(event));
    });
  }

  /// Marks [id] as in-flight. Events in this state are reclaimed on startup.
  Future<void> markProcessing(int id, {required DateTime at}) {
    return guard('mark_processing', () async {
      final Database db = await dbConnection;
      await db.update(
        SyncEventModel.table,
        <String, Object?>{
          'status': SyncStatus.processing.name,
          'updated_at': at.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }

  /// Marks [id] as successfully delivered.
  Future<void> markSuccess(
    int id, {
    required DateTime at,
    required DateTime syncedAt,
  }) {
    return guard('mark_success', () async {
      final Database db = await dbConnection;
      await db.update(
        SyncEventModel.table,
        <String, Object?>{
          'status': SyncStatus.completed.name,
          'updated_at': at.millisecondsSinceEpoch,
          'synced_at': syncedAt.millisecondsSinceEpoch,
          'last_error': null,
          'next_retry_at': null,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }

  /// Marks [id] as a transient failure eligible for retry after [nextRetryAt].
  Future<void> markRetryableFailure(
    int id, {
    required String lastError,
    required int retryCount,
    required DateTime at,
    required DateTime nextRetryAt,
  }) {
    return guard('mark_retryable_failure', () async {
      final Database db = await dbConnection;
      await db.update(
        SyncEventModel.table,
        <String, Object?>{
          'status': SyncStatus.failedRetryable.name,
          'retry_count': retryCount,
          'last_error': lastError,
          'next_retry_at': nextRetryAt.millisecondsSinceEpoch,
          'updated_at': at.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }

  /// Marks [id] as a permanent (terminal) failure.
  Future<void> markPermanentFailure(
    int id, {
    required String lastError,
    required int retryCount,
    required DateTime at,
  }) {
    return guard('mark_permanent_failure', () async {
      final Database db = await dbConnection;
      await db.update(
        SyncEventModel.table,
        <String, Object?>{
          'status': SyncStatus.failedPermanent.name,
          'retry_count': retryCount,
          'last_error': lastError,
          'updated_at': at.millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }

  /// Reclaims PROCESSING events for [userId] that have been in-flight longer
  /// than [olderThan] (e.g. a crashed sync run). Returns the reclaimed ids.
  Future<List<int>> resetStuckProcessingEvents(
    String userId, {
    required DateTime olderThan,
    required DateTime at,
  }) {
    return guard('reset_stuck_processing', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> stuck = await db.query(
        SyncEventModel.table,
        columns: <String>['id'],
        where:
            'user_id = ? AND status = ? AND updated_at < ?',
        whereArgs: <Object?>[
          userId,
          SyncStatus.processing.name,
          olderThan.millisecondsSinceEpoch,
        ],
      );
      if (stuck.isEmpty) return <int>[];
      final List<int> ids = stuck
          .map((Map<String, Object?> row) => row['id'] as int)
          .toList();
      final String placeholders =
          List<String>.filled(ids.length, '?').join(',');
      await db.update(
        SyncEventModel.table,
        <String, Object?>{
          'status': SyncStatus.pending.name,
          'next_retry_at': null,
          'last_error': 'reclaimed_stuck_processing',
          'updated_at': at.millisecondsSinceEpoch,
        },
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
      return ids;
    });
  }

  /// Returns events for [userId] that are eligible for processing right now:
  /// pending or retryable events whose `next_retry_at` has passed.
  Future<List<SyncEvent>> getRetryableByUserId(
    String userId, {
    int? limit,
    int? offset,
    DateTime? now,
  }) {
    return guard('get_retryable_by_user', () async {
      final Database db = await dbConnection;
      final int nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
      final List<Map<String, Object?>> rows = await db.query(
        SyncEventModel.table,
        where:
            'user_id = ? AND status IN (?, ?) AND (next_retry_at IS NULL OR '
            'next_retry_at <= ?)',
        whereArgs: <Object?>[
          userId,
          SyncStatus.pending.name,
          SyncStatus.failedRetryable.name,
          nowMs,
        ],
        // ORDER BY must be stable: the outbox drain paginates with LIMIT/OFFSET
        // over a set that shrinks as rows transition to PROCESSING/COMPLETED.
        // `id` (AUTOINCREMENT, monotonic with enqueue order) is the tie-breaker
        // so OFFSET never skips or re-reads an event when `created_at` ties
        // (PROMPT 20/21).
        orderBy: 'created_at ASC, id ASC',
        limit: limit,
        offset: offset,
      );
      return rows.map(SyncEventModel.fromMap).toList();
    });
  }

  /// Number of events waiting to be sent (pending + retryable).
  Future<int> getPendingCount(String userId) {
    return guard('get_pending_count', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM sync_event WHERE user_id = ? '
        'AND status IN (?, ?)',
        <Object?>[
          userId,
          SyncStatus.pending.name,
          SyncStatus.failedRetryable.name,
        ],
      );
      return (rows.first['count'] as num).toInt();
    });
  }

  /// Number of permanently failed events for [userId].
  Future<int> getFailedCount(String userId) {
    return guard('get_failed_count', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM sync_event WHERE user_id = ? '
        'AND status IN (?, ?)',
        <Object?>[
          userId,
          SyncStatus.failedPermanent.name,
          SyncStatus.failed.name,
        ],
      );
      return (rows.first['count'] as num).toInt();
    });
  }

  Future<void> update(SyncEvent event) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        SyncEventModel.table,
        SyncEventModel.toMap(event),
        where: 'id = ?',
        whereArgs: <Object?>[event.id],
      );
    });
  }

  Future<void> updateAll(List<SyncEvent> events) {
    return guard('update_all', () async {
      final Database db = await dbConnection;
      final Batch batch = db.batch();
      for (final SyncEvent event in events) {
        batch.update(
          SyncEventModel.table,
          SyncEventModel.toMap(event),
          where: 'id = ?',
          whereArgs: <Object?>[event.id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Developer recovery: re-queues every non-final event for [userId] back to
  /// PENDING with a zeroed retry counter so the next sync run retries them
  /// (used from the developer diagnostics screen).
  Future<void> requeueAllByUserId(String userId, {required DateTime at}) {
    return guard('requeue_all_by_user', () async {
      final Database db = await dbConnection;
      await db.update(
        SyncEventModel.table,
        <String, Object?>{
          'status': SyncStatus.pending.name,
          'retry_count': 0,
          'next_retry_at': null,
          'last_error': 'requeued_manually',
          'updated_at': at.millisecondsSinceEpoch,
        },
        where: 'user_id = ? AND status IN (?, ?, ?, ?, ?)',
        whereArgs: <Object?>[
          userId,
          SyncStatus.pending.name,
          SyncStatus.failedRetryable.name,
          SyncStatus.processing.name,
          SyncStatus.failedPermanent.name,
          SyncStatus.failed.name,
        ],
      );
    });
  }

  /// Returns all events for [userId] that have not reached a final state
  /// (pending, retryable, processing or permanently failed), oldest first.
  /// Used by developer diagnostics to surface stuck outbox events.
  Future<List<SyncEvent>> getNonCompletedByUserId(
    String userId, {
    int limit = 100,
  }) {
    return guard('get_non_completed_by_user', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        SyncEventModel.table,
        where: 'user_id = ? AND status IN (?, ?, ?, ?, ?)',
        whereArgs: <Object?>[
          userId,
          SyncStatus.pending.name,
          SyncStatus.failedRetryable.name,
          SyncStatus.processing.name,
          SyncStatus.failedPermanent.name,
          SyncStatus.failed.name,
        ],
        orderBy: 'created_at ASC, id ASC',
        limit: limit,
      );
      return rows.map(SyncEventModel.fromMap).toList();
    });
  }

  Future<List<SyncEvent>> getPendingByUserId(
    String userId, {
    int? limit,
    int? offset,
  }) {
    return guard('get_pending_by_user', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        SyncEventModel.table,
        where: 'user_id = ? AND status = ?',
        whereArgs: <Object?>[userId, SyncStatus.pending.name],
        orderBy: 'created_at ASC',
        limit: limit,
        offset: offset,
      );
      return rows.map(SyncEventModel.fromMap).toList();
    });
  }

  Future<SyncEvent?> findDuplicate(
    String userId,
    String entity,
    String entityId,
    SyncOperation operation,
  ) {
    return guard('find_duplicate', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        SyncEventModel.table,
        where:
            'user_id = ? AND entity = ? AND entity_id = ? AND operation = ? '
            'AND status = ?',
        whereArgs: <Object?>[
          userId,
          entity,
          entityId,
          operation.name,
          SyncStatus.pending.name,
        ],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return SyncEventModel.fromMap(rows.first);
    });
  }

  Future<Map<String, int>> countByStatus(String userId) {
    return guard('count_by_status', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT status, COUNT(*) AS count FROM sync_event '
        'WHERE user_id = ? GROUP BY status',
        <Object?>[userId],
      );
      final Map<String, int> counts = <String, int>{};
      for (final Map<String, Object?> row in rows) {
        counts[row['status'] as String] = (row['count'] as num).toInt();
      }
      return counts;
    });
  }

  Future<DateTime?> latestSyncedAt(String userId) {
    return guard('latest_synced_at', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        SyncEventModel.table,
        columns: <String>['synced_at'],
        where: 'user_id = ? AND synced_at IS NOT NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'synced_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return DateTime.fromMillisecondsSinceEpoch(rows.first['synced_at'] as int);
    });
  }

  Future<void> deleteCompletedOlderThan(String userId, DateTime threshold) {
    return guard('delete_completed_older_than', () async {
      final Database db = await dbConnection;
      await db.delete(
        SyncEventModel.table,
        where: 'user_id = ? AND status = ? AND updated_at < ?',
        whereArgs: <Object?>[
          userId,
          SyncStatus.completed.name,
          threshold.millisecondsSinceEpoch,
        ],
      );
    });
  }

  Future<void> deleteCompletedOlderThanAll(DateTime threshold) {
    return guard('delete_completed_older_than_all', () async {
      final Database db = await dbConnection;
      await db.delete(
        SyncEventModel.table,
        where: 'status = ? AND updated_at < ?',
        whereArgs: <Object?>[
          SyncStatus.completed.name,
          threshold.millisecondsSinceEpoch,
        ],
      );
    });
  }
}
