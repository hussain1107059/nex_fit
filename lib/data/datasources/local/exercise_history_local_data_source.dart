import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/exercise_history.dart';
import '../../models/exercise_history_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `exercise_history` table.
///
/// Sync-aware (PROMPT 12 Batch 2): every user-owned mutation runs inside a
/// transaction together with its outbox event. The owning `user_id` is resolved
/// from the parent `workout_history` row; `uuid`, `created_at`, `updated_at`,
/// `row_version` and `deleted_at` are maintained by the DAO while the domain
/// entity keeps its existing shape. Rows without a resolvable owner produce no
/// sync events.
class ExerciseHistoryLocalDataSource extends BaseLocalDataSource {
  ExerciseHistoryLocalDataSource({required super.database})
    : super(logName: 'ExerciseHistoryLocalDataSource');

  Future<int> insert(ExerciseHistory history) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = ExerciseHistoryModel.toMap(history);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final String? userId = await _ownerUserId(txn, history.workoutHistoryId);
        if (userId != null) values['user_id'] = userId;
        final int id = await txn.insert(ExerciseHistoryModel.table, values);
        if (userId != null) {
          await SyncableDao.recordCreate(
            txn,
            entity: ExerciseHistoryModel.table,
            entityId: '$id',
            userId: userId,
          );
        }
        return id;
      });
    });
  }

  Future<void> update(ExerciseHistory history) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, history.id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        final Map<String, Object?> values = ExerciseHistoryModel.toMap(history);
        values['id'] = existing['id'];
        values['uuid'] = existing['uuid'] as String;
        values['user_id'] = existing['user_id'];
        values['created_at'] = existing['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          ExerciseHistoryModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[history.id],
        );
        final String? userId = existing['user_id'] as String?;
        if (userId != null) {
          await SyncableDao.recordUpdate(
            txn,
            entity: ExerciseHistoryModel.table,
            entityId: '${history.id}',
            userId: userId,
            baseVersion: baseVersion,
          );
        }
      });
    });
  }

  Future<ExerciseHistory?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ExerciseHistoryModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ExerciseHistoryModel.fromMap(rows.first);
    });
  }

  Future<List<ExerciseHistory>> getByWorkoutHistory(int workoutHistoryId) {
    return guard('get_by_workout_history', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ExerciseHistoryModel.table,
        where: 'workout_history_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[workoutHistoryId],
        orderBy: 'id ASC',
      );
      return rows.map(ExerciseHistoryModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        await txn.update(
          ExerciseHistoryModel.table,
          <String, Object?>{
            'deleted_at': now,
            'updated_at': now,
            'row_version': baseVersion + 1,
          },
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        final String? userId = existing['user_id'] as String?;
        if (userId != null) {
          await SyncableDao.recordDelete(
            txn,
            entity: ExerciseHistoryModel.table,
            entityId: '$id',
            userId: userId,
            baseVersion: baseVersion,
          );
        }
      });
    });
  }

  Future<Map<String, Object?>?> _findRow(Transaction txn, int? id) async {
    if (id == null) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      ExerciseHistoryModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<String?> _ownerUserId(Transaction txn, int workoutHistoryId) async {
    final List<Map<String, Object?>> rows = await txn.query(
      'workout_history',
      columns: const <String>['user_id'],
      where: 'id = ?',
      whereArgs: <Object?>[workoutHistoryId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['user_id'] as String?;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}