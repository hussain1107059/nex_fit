import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/fitness_goal.dart';
import '../../models/fitness_goal_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `fitness_goal` table.
///
/// Sync-aware (PROMPT 11 Batch 1): every user-owned mutation runs inside a
/// transaction together with its outbox event, and sync columns (`uuid`,
/// `created_at`, `updated_at`, `row_version`, `deleted_at`) are maintained by
/// the DAO while the domain entity keeps its existing shape. Rows without a
/// `user_id` are master templates and never produce sync events.
class FitnessGoalLocalDataSource extends BaseLocalDataSource {
  FitnessGoalLocalDataSource({required super.database})
    : super(logName: 'FitnessGoalLocalDataSource');

  Future<int> insert(FitnessGoal goal) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = FitnessGoalModel.toMap(goal);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = values['created_at'] ?? now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final int id = await txn.insert(FitnessGoalModel.table, values);
        final String? userId = goal.userId;
        if (userId != null) {
          await SyncableDao.recordCreate(
            txn,
            entity: FitnessGoalModel.table,
            entityId: '$id',
            userId: userId,
          );
        }
        return id;
      });
    });
  }

  Future<void> update(FitnessGoal goal) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, goal.id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        final Map<String, Object?> values = FitnessGoalModel.toMap(goal);
        values['uuid'] = existing['uuid'] as String;
        values['created_at'] = values['created_at'] ?? existing['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          FitnessGoalModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[goal.id],
        );
        final String? userId = goal.userId ?? existing['user_id'] as String?;
        if (userId != null) {
          await SyncableDao.recordUpdate(
            txn,
            entity: FitnessGoalModel.table,
            entityId: '${goal.id}',
            userId: userId,
            baseVersion: baseVersion,
          );
        }
      });
    });
  }

  Future<FitnessGoal?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FitnessGoalModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return FitnessGoalModel.fromMap(rows.first);
    });
  }

  Future<List<FitnessGoal>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FitnessGoalModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'updated_at DESC',
      );
      return rows.map(FitnessGoalModel.fromMap).toList();
    });
  }

  Future<List<FitnessGoal>> getTemplates() {
    return guard('get_templates', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FitnessGoalModel.table,
        where: 'user_id IS NULL AND deleted_at IS NULL',
        orderBy: 'id ASC',
      );
      return rows.map(FitnessGoalModel.fromMap).toList();
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
        await _softDelete(txn, id, now: now, baseVersion: baseVersion);
        final String? userId = existing['user_id'] as String?;
        if (userId != null) {
          await SyncableDao.recordDelete(
            txn,
            entity: FitnessGoalModel.table,
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
      FitnessGoalModel.table,
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
      FitnessGoalModel.table,
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
