import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/food_item.dart';
import '../../../domain/entities/food_log.dart';
import '../../models/food_item_model.dart';
import '../../models/food_log_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `food_log` table.
class FoodLogLocalDataSource extends BaseLocalDataSource {
  FoodLogLocalDataSource({required super.database})
    : super(logName: 'FoodLogLocalDataSource');

  Future<int> insert(FoodLog log) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        FoodLogModel.table,
        FoodLogModel.toMap(log),
      );
    });
  }

  Future<void> insertAll(List<FoodLog> logs) {
    return guard('insert_all', () async {
      final Database db = await dbConnection;
      final Batch batch = db.batch();
      for (final FoodLog log in logs) {
        batch.insert(
          FoodLogModel.table,
          FoodLogModel.toMap(log),
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> update(FoodLog log) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        FoodLogModel.table,
        FoodLogModel.toMap(log),
        where: 'id = ?',
        whereArgs: <Object?>[log.id],
      );
    });
  }

  Future<FoodLog?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FoodLogModel.table,
        where: 'id = ?',
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
        where: 'user_id = ?',
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
        where: 'user_id = ? AND logged_at >= ? AND logged_at < ?',
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
        'WHERE fl.user_id = ? '
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
        'WHERE fl.user_id = ? '
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
      await db.delete(
        FoodLogModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
