import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/meal.dart';
import '../../models/meal_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `meal` table.
class MealLocalDataSource extends BaseLocalDataSource {
  MealLocalDataSource({required super.database})
    : super(logName: 'MealLocalDataSource');

  Future<int> insert(Meal meal) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        MealModel.table,
        MealModel.toMap(meal),
      );
    });
  }

  Future<void> update(Meal meal) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        MealModel.table,
        MealModel.toMap(meal),
        where: 'id = ?',
        whereArgs: <Object?>[meal.id],
      );
    });
  }

  Future<Meal?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        MealModel.table,
        where: 'id = ?',
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
        where: 'user_id = ?',
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
        where: 'user_id = ? AND is_favorite = 1',
        whereArgs: <Object?>[userId],
        orderBy: 'name ASC',
      );
      return rows.map(MealModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        MealModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
