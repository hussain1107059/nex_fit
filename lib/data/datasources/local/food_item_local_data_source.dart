import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/food_item.dart';
import '../../models/food_item_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `food_item` table (built-in + user foods).
class FoodItemLocalDataSource extends BaseLocalDataSource {
  FoodItemLocalDataSource({required super.database})
    : super(logName: 'FoodItemLocalDataSource');

  Future<int> insert(FoodItem item) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        FoodItemModel.table,
        FoodItemModel.toMap(item),
      );
    });
  }

  Future<void> update(FoodItem item) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        FoodItemModel.table,
        FoodItemModel.toMap(item),
        where: 'id = ?',
        whereArgs: <Object?>[item.id],
      );
    });
  }

  Future<FoodItem?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FoodItemModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return FoodItemModel.fromMap(rows.first);
    });
  }

  Future<List<FoodItem>> getBuiltIn() {
    return guard('get_built_in', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FoodItemModel.table,
        where: 'user_id IS NULL',
        orderBy: 'name ASC',
      );
      return rows.map(FoodItemModel.fromMap).toList();
    });
  }

  Future<List<FoodItem>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        FoodItemModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'name ASC',
      );
      return rows.map(FoodItemModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        FoodItemModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
