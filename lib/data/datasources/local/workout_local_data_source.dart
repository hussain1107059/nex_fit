import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/workout.dart';
import '../../models/workout_exercise_model.dart';
import '../../models/workout_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `workout` table.
///
/// Sync-aware (PROMPT 11 Batch 1): every mutation runs inside a transaction
/// with its outbox event; sync columns are maintained by the DAO. Deleting a
/// workout tombstones it AND its `workout_exercise` children (mirroring the
/// legacy `ON DELETE CASCADE` with soft-deletes so both stay consistent on the
/// cloud).
class WorkoutLocalDataSource extends BaseLocalDataSource {
  WorkoutLocalDataSource({required super.database})
    : super(logName: 'WorkoutLocalDataSource');

  Future<int> insert(Workout workout) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = WorkoutModel.toMap(workout);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = values['created_at'] ?? now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final int id = await txn.insert(WorkoutModel.table, values);
        await SyncableDao.recordCreate(
          txn,
          entity: WorkoutModel.table,
          entityId: '$id',
          userId: workout.userId,
        );
        return id;
      });
    });
  }

  Future<void> update(Workout workout) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, workout.id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        final Map<String, Object?> values = WorkoutModel.toMap(workout);
        values['uuid'] = existing['uuid'] as String;
        values['created_at'] = values['created_at'] ?? existing['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          WorkoutModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[workout.id],
        );
        await SyncableDao.recordUpdate(
          txn,
          entity: WorkoutModel.table,
          entityId: '${workout.id}',
          userId: workout.userId,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<Workout?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return WorkoutModel.fromMap(rows.first);
    });
  }

  Future<List<Workout>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'updated_at DESC',
      );
      return rows.map(WorkoutModel.fromMap).toList();
    });
  }

  Future<List<Workout>> getByCategory(int categoryId) {
    return guard('get_by_category', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutModel.table,
        where: 'category_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[categoryId],
        orderBy: 'name ASC',
      );
      return rows.map(WorkoutModel.fromMap).toList();
    });
  }

  Future<List<Workout>> getByCategoryForUser(
    String userId,
    int categoryId,
  ) {
    return guard('get_by_category_for_user', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutModel.table,
        where: 'user_id = ? AND category_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId, categoryId],
        orderBy: 'name ASC',
      );
      return rows.map(WorkoutModel.fromMap).toList();
    });
  }

  Future<List<Workout>> getFavorites(String userId) {
    return guard('get_favorites', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutModel.table,
        where: 'user_id = ? AND is_favorite = 1 AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'updated_at DESC',
      );
      return rows.map(WorkoutModel.fromMap).toList();
    });
  }

  Future<List<Workout>> getByIds(List<int> ids) {
    return guard('get_by_ids', () async {
      if (ids.isEmpty) return const <Workout>[];
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutModel.table,
        where: 'id IN (${List<String>.filled(ids.length, '?').join(', ')}) '
            'AND deleted_at IS NULL',
        whereArgs: ids,
      );
      return rows.map(WorkoutModel.fromMap).toList();
    });
  }

  Future<int> countByUser(String userId) {
    return guard('count_by_user', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM ${WorkoutModel.table} '
        'WHERE user_id = ? AND deleted_at IS NULL',
        <Object?>[userId],
      );
      return rows.first['count'] as int? ?? 0;
    });
  }

  Future<int> countBuiltInByUser(String userId) {
    return guard('count_built_in', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM ${WorkoutModel.table} '
        'WHERE user_id = ? AND is_custom = 0 AND deleted_at IS NULL',
        <Object?>[userId],
      );
      return rows.first['count'] as int? ?? 0;
    });
  }

  Future<void> setFavorite(int id, bool favorite) {
    return guard('set_favorite', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        await txn.update(
          WorkoutModel.table,
          <String, Object?>{
            'is_favorite': favorite ? 1 : 0,
            'updated_at': now,
            'row_version': baseVersion + 1,
          },
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        await SyncableDao.recordUpdate(
          txn,
          entity: WorkoutModel.table,
          entityId: '$id',
          userId: existing['user_id'] as String,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, id);
        if (existing == null) return;
        final String userId = existing['user_id'] as String;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        await _softDelete(txn, id, now: now, baseVersion: baseVersion);
        await SyncableDao.recordDelete(
          txn,
          entity: WorkoutModel.table,
          entityId: '$id',
          userId: userId,
          baseVersion: baseVersion,
        );
        // Tombstone the child join rows too (mirrors the legacy ON DELETE
        // CASCADE using soft-deletes so remote state stays consistent).
        final List<Map<String, Object?>> children = await txn.query(
          WorkoutExerciseModel.table,
          columns: const <String>['id', 'row_version'],
          where: 'workout_id = ? AND deleted_at IS NULL',
          whereArgs: <Object?>[id],
        );
        for (final Map<String, Object?> child in children) {
          final int childId = child['id'] as int;
          final int childVersion = _version(child);
          await _softDeleteChild(
            txn,
            childId,
            now: now,
            baseVersion: childVersion,
          );
          await SyncableDao.recordDelete(
            txn,
            entity: WorkoutExerciseModel.table,
            entityId: '$childId',
            userId: userId,
            baseVersion: childVersion,
          );
        }
      });
    });
  }

  Future<Map<String, Object?>?> _findRow(Transaction txn, int? id) async {
    if (id == null) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      WorkoutModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _softDelete(
    Transaction txn,
    int id, {
    required int now,
    required int baseVersion,
  }) async {
    await txn.update(
      WorkoutModel.table,
      <String, Object?>{
        'deleted_at': now,
        'updated_at': now,
        'row_version': baseVersion + 1,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> _softDeleteChild(
    Transaction txn,
    int id, {
    required int now,
    required int baseVersion,
  }) async {
    await txn.update(
      WorkoutExerciseModel.table,
      <String, Object?>{
        'deleted_at': now,
        'updated_at': now,
        'row_version': baseVersion + 1,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}