import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/meal_item.dart';
import '../../models/meal_item_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `meal_item` join table (child of `meal`).
///
/// Sync-aware (PROMPT 12 Batch 2): the owning `user_id` is resolved from the
/// parent `meal` row and the mutation + outbox event commit atomically. Reads
/// filter out tombstones so soft-deleted children are never surfaced.
class MealItemLocalDataSource extends BaseLocalDataSource {
  MealItemLocalDataSource({required super.database})
    : super(logName: 'MealItemLocalDataSource');

  Future<int> insert(MealItem item) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = MealItemModel.toMap(item);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final String? userId = await _ownerUserId(txn, item.mealId);
        if (userId != null) values['user_id'] = userId;
        final int id = await txn.insert(MealItemModel.table, values);
        if (userId != null) {
          await SyncableDao.recordCreate(
            txn,
            entity: MealItemModel.table,
            entityId: '$id',
            userId: userId,
          );
        }
        return id;
      });
    });
  }

  /// Inserts many items in a single transaction; each resolves its owner and
  /// gets a CREATE event, without loading any table into memory.
  Future<void> insertAll(List<MealItem> items) {
    return guard('insert_all', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        for (final MealItem item in items) {
          final Map<String, Object?> values = MealItemModel.toMap(item);
          values['uuid'] = SyncableDao.newUuid();
          values['created_at'] = now;
          values['updated_at'] = now;
          values['row_version'] = SyncableDao.firstRowVersion;
          final String? userId = await _ownerUserId(txn, item.mealId);
          if (userId != null) values['user_id'] = userId;
          final int id = await txn.insert(MealItemModel.table, values);
          if (userId != null) {
            await SyncableDao.recordCreate(
              txn,
              entity: MealItemModel.table,
              entityId: '$id',
              userId: userId,
            );
          }
        }
      });
    });
  }

  Future<void> update(MealItem item) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, item.id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        final Map<String, Object?> values = MealItemModel.toMap(item);
        values['id'] = existing['id'];
        values['uuid'] = existing['uuid'] as String;
        values['user_id'] = existing['user_id'];
        values['created_at'] = existing['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          MealItemModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[item.id],
        );
        final String? userId = existing['user_id'] as String?;
        if (userId != null) {
          await SyncableDao.recordUpdate(
            txn,
            entity: MealItemModel.table,
            entityId: '${item.id}',
            userId: userId,
            baseVersion: baseVersion,
          );
        }
      });
    });
  }

  Future<List<MealItem>> getByMeal(int mealId) {
    return guard('get_by_meal', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        MealItemModel.table,
        where: 'meal_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[mealId],
        orderBy: 'sort_order ASC',
      );
      return rows.map(MealItemModel.fromMap).toList();
    });
  }

  /// Fetches the items of many meals in a single query (avoids an N+1 when
  /// loading a whole template collection).
  Future<List<MealItem>> getByMeals(List<int> mealIds) {
    return guard('get_by_meals', () async {
      if (mealIds.isEmpty) return const <MealItem>[];
      final Database db = await dbConnection;
      final String placeholders = List.filled(mealIds.length, '?').join(', ');
      final List<Map<String, Object?>> rows = await db.query(
        MealItemModel.table,
        where: 'meal_id IN ($placeholders) AND deleted_at IS NULL',
        whereArgs: mealIds,
        orderBy: 'sort_order ASC',
      );
      return rows.map(MealItemModel.fromMap).toList();
    });
  }

  /// Soft-deletes every item of [mealId], each with a DELETE event.
  Future<void> deleteByMeal(int mealId) {
    return guard('delete_by_meal', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final List<Map<String, Object?>> children = await txn.query(
          MealItemModel.table,
          where: 'meal_id = ?',
          whereArgs: <Object?>[mealId],
        );
        final int now = SyncableDao.nowMs();
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
      });
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
          MealItemModel.table,
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
            entity: MealItemModel.table,
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
      MealItemModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<String?> _ownerUserId(Transaction txn, int mealId) async {
    final List<Map<String, Object?>> rows = await txn.query(
      'meal',
      columns: const <String>['user_id'],
      where: 'id = ?',
      whereArgs: <Object?>[mealId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['user_id'] as String?;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}