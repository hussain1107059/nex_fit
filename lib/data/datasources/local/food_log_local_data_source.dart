import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/food_item.dart';
import '../../../domain/entities/food_log.dart';
import '../../models/food_item_model.dart';
import '../../models/food_log_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `food_log` table.
///
/// Sync-aware (PROMPT 12 Batch 2): every mutation runs inside a transaction
/// together with its outbox event. Nutrition tables can grow very large, so no
/// operation loads an entire table into memory: bulk writes go through a single
/// batched transaction and reads always target a single row or a bounded
/// date/user range.
class FoodLogLocalDataSource extends BaseLocalDataSource {
  FoodLogLocalDataSource({required super.database})
    : super(logName: 'FoodLogLocalDataSource');

  Future<int> insert(FoodLog log) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values = FoodLogModel.toMap(log);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = values['created_at'] ?? now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final int id = await txn.insert(FoodLogModel.table, values);
        await SyncableDao.recordCreate(
          txn,
          entity: FoodLogModel.table,
          entityId: '$id',
          userId: log.userId,
        );
        return id;
      });
    });
  }

  /// Inserts many logs in a single transaction (never loads the table into
  /// memory); each row gets its own uuid and CREATE outbox event.
  Future<void> insertAll(List<FoodLog> logs) {
    return guard('insert_all', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        for (final FoodLog log in logs) {
          final Map<String, Object?> values = FoodLogModel.toMap(log);
          values['uuid'] = SyncableDao.newUuid();
          values['created_at'] = values['created_at'] ?? now;
          values['updated_at'] = now;
          values['row_version'] = SyncableDao.firstRowVersion;
          final int id = await txn.insert(FoodLogModel.table, values);
          await SyncableDao.recordCreate(
            txn,
            entity: FoodLogModel.table,
            entityId: '$id',
            userId: log.userId,
          );
        }
      });
    });
  }

  Future<void> update(FoodLog log) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, log.id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        final Map<String, Object?> values = FoodLogModel.toMap(log);
        values['id'] = existing['id'];
        values['uuid'] = existing['uuid'] as String;
        values['created_at'] = values['created_at'] ?? existing['created_at'];
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          FoodLogModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[log.id],
        );
        final String userId = log.userId;
        await SyncableDao.recordUpdate(
          txn,
          entity: FoodLogModel.table,
          entityId: '${log.id}',
          userId: userId,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<FoodLog?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FoodLogModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return FoodLogModel.fromMap(rows.first);
    });
  }

  Future<List<FoodLog>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FoodLogModel.table,
        where: 'user_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[userId],
        orderBy: 'logged_at DESC',
      );
      return rows.map(FoodLogModel.fromMap).toList();
    });
  }

  Future<List<FoodLog>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return guard('get_by_date_range', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FoodLogModel.table,
        where:
            'user_id = ? AND deleted_at IS NULL AND logged_at >= ? AND logged_at < ?',
        whereArgs: <Object?>[
          userId,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
        orderBy: 'logged_at ASC',
      );
      return rows.map(FoodLogModel.fromMap).toList();
    });
  }

  /// The most recently logged foods (distinct, deduplicated by name).
  Future<List<FoodItem>> getRecentFoods(String userId, {int limit = 12}) {
    return guard('get_recent_foods', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT fi.* FROM food_log fl '
        'INNER JOIN ${FoodItemModel.table} fi ON fi.id = fl.food_item_id '
        'WHERE fl.user_id = ? AND fl.deleted_at IS NULL '
        'GROUP BY fl.food_item_id '
        'ORDER BY MAX(fl.logged_at) DESC '
        'LIMIT ?',
        <Object?>[userId, limit],
      );
      return rows.map(FoodItemModel.fromMap).toList();
    });
  }

  /// The most frequently logged foods (distinct, ordered by usage).
  Future<List<FoodItem>> getFrequentFoods(String userId, {int limit = 12}) {
    return guard('get_frequent_foods', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT fi.*, COUNT(fl.id) AS usage_count FROM food_log fl '
        'INNER JOIN ${FoodItemModel.table} fi ON fi.id = fl.food_item_id '
        'WHERE fl.user_id = ? AND fl.deleted_at IS NULL '
        'GROUP BY fl.food_item_id '
        'ORDER BY usage_count DESC, MAX(fl.logged_at) DESC '
        'LIMIT ?',
        <Object?>[userId, limit],
      );
      return rows.map(FoodItemModel.fromMap).toList();
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
          FoodLogModel.table,
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
          entity: FoodLogModel.table,
          entityId: '$id',
          userId: existing['user_id'] as String,
          baseVersion: baseVersion,
        );
      });
    });
  }

  Future<Map<String, Object?>?> _findRow(Transaction txn, int? id) async {
    if (id == null) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      FoodLogModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;
}