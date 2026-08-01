import 'dart:async';

import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/security_enums.dart';
import '../../../domain/entities/weight_log.dart';
import '../../models/weight_log_model.dart';
import '../../services/sync/sync_event_recorder.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `weight_log` table.
class WeightLogLocalDataSource extends BaseLocalDataSource {
  WeightLogLocalDataSource({required super.database})
    : super(logName: 'WeightLogLocalDataSource');

  Future<int> insert(WeightLog log) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      final int id = await db.insert(
        WeightLogModel.table,
        WeightLogModel.toMap(log),
      );
      unawaited(
        SyncEventRecorder.record(
          entity: WeightLogModel.table,
          entityId: '$id',
          operation: SyncOperation.create,
          userId: log.userId,
        ),
      );
      return id;
    });
  }

  Future<void> update(WeightLog log) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        WeightLogModel.table,
        WeightLogModel.toMap(log),
        where: 'id = ?',
        whereArgs: <Object?>[log.id],
      );
      unawaited(
        SyncEventRecorder.record(
          entity: WeightLogModel.table,
          entityId: '${log.id}',
          operation: SyncOperation.update,
          userId: log.userId,
        ),
      );
    });
  }

  Future<WeightLog?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WeightLogModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return WeightLogModel.fromMap(rows.first);
    });
  }

  Future<List<WeightLog>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WeightLogModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'logged_at DESC',
      );
      return rows.map(WeightLogModel.fromMap).toList();
    });
  }

  Future<List<WeightLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return guard('get_by_date_range', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WeightLogModel.table,
        where: 'user_id = ? AND logged_at >= ? AND logged_at < ?',
        whereArgs: <Object?>[
          userId,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
        orderBy: 'logged_at DESC',
      );
      return rows.map(WeightLogModel.fromMap).toList();
    });
  }

  Future<WeightLog?> getLatest(String userId) {
    return guard('get_latest', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WeightLogModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'logged_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return WeightLogModel.fromMap(rows.first);
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        WeightLogModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      unawaited(
        SyncEventRecorder.record(
          entity: WeightLogModel.table,
          entityId: '$id',
          operation: SyncOperation.delete,
        ),
      );
    });
  }
}
