import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/meal.dart';
import '../../models/meal_item_model.dart';
import '../../models/meal_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `meal` table (parent of `meal_item`).
///
/// Sync-aware (PROMPT 12 Batch 2): every mutation runs inside a transaction
/// together with its outbox event. Deleting a meal also tombstones its
/// `meal_item` children (mirroring the legacy ON DELETE CASCADE) so no orphaned
/// active child can outlive its parent locally.
class MealLocalDataSource extends BaseLocalDataSource {
  MealLocalDataSource({required super.database})
    : super(logName: 'MealLocalDataSource');

  Future<int> insert(Meal meal) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = MealModel.toMap(meal);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = values['created_at'] ?? now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final int id = await txn.insert(MealModel.table, values);
        await SyncableDao.recordCreate(
          txn,
          entity: MealModel.table,
          entityId: '$id',
          userId: meal.userId,
        );
        return id;
      });
    });
  }

  Future<void> update(Meal meal) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, meal.id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        final Map<String, Object?> values = MealModel.toMap(meal);
        values['id'] = existing['id'];
        values['uuid'] = existing['uuid'] as String;
        values['created_at'] = values['created_at'] ?? existing['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          MealModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[meal.id],
        );
        await SyncableDao.recordUpdate(
          txn,
          entity: MealModel.table,
          entityId: '${meal.id}',
          userId: meal.userId,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<Meal?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        MealModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return MealModel.fromMap(rows.first);
    });
  }

  Future<List<Meal>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        MealModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'name ASC',
      );
      return rows.map(MealModel.fromMap).toList();
    });
  }

  Future<List<Meal>> getFavorites(String userId) {
    return guard('get_favorites', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        MealModel.table,
        where: 'user_id = ? AND is_favorite = 1 AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'name ASC',
      );
      return rows.map(MealModel.fromMap).toList();
    });
  }

  /// Soft-deletes the meal and tombstones its `meal_item` children (each with a
  /// DELETE outbox event) so parent/child consistency is preserved.
  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        await txn.update(
          MealModel.table,
          <String, Object?>{
            'deleted_at': now,
            'updated_at': now,
            'row_version': baseVersion + 1,
          },
          where: 'id = ?',
          whereArgs: <Object?>[id],
        );
        await SyncableDao.recordDelete(
          txn,
          entity: MealModel.table,
          entityId: '$id',
          userId: existing['user_id'] as String,
          baseVersion: baseVersion,
        );
        await _tombstoneChildren(txn, id, now);
      });
    });
  }

  Future<void> _tombstoneChildren(Transaction txn, int mealId, int now) async {
    final List<Map<String, Object?>> children = await txn.query(
      MealItemModel.table,
      where: 'meal_id = ?',
      whereArgs: <Object?>[mealId],
    );
    for (final Map<String, Object?> child in children) {
      final int baseVersion = _version(child);
      await txn.update(
        MealItemModel.table,
        <String, Object?>{
          'deleted_at': now,
          'updated_at': now,
          'row_version': baseVersion + 1,
        },
        where: 'id = ?',
        whereArgs: <Object?>[child['id']],
      );
      final String? userId = child['user_id'] as String?;
      if (userId != null) {
        await SyncableDao.recordDelete(
          txn,
          entity: MealItemModel.table,
          entityId: '${child['id']}',
          userId: userId,
          baseVersion: baseVersion,
        );
      }
    }
  }

  Future<Map<String, Object?>?> _findRow(Transaction txn, int? id) async {
    if (id == null) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      MealModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}