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

  Future<List<SyncEvent>> getPendingByUserId(String userId) {
    return guard('get_pending_by_user', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        SyncEventModel.table,
        where: 'user_id = ? AND status = ?',
        whereArgs: <Object?>[userId, SyncStatus.pending.name],
        orderBy: 'created_at ASC',
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
