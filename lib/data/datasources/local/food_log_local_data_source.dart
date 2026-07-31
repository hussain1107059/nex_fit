import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/food_log.dart';
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
        orderBy: 'logged_at DESC',
      );
      return rows.map(FoodLogModel.fromMap).toList();
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
