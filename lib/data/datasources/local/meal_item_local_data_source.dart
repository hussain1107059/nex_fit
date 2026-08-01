import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/meal_item.dart';
import '../../models/meal_item_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `meal_item` join table.
class MealItemLocalDataSource extends BaseLocalDataSource {
  MealItemLocalDataSource({required super.database})
    : super(logName: 'MealItemLocalDataSource');

  Future<int> insert(MealItem item) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        MealItemModel.table,
        MealItemModel.toMap(item),
      );
    });
  }

  Future<void> insertAll(List<MealItem> items) {
    return guard('insert_all', () async {
      final Database db = await dbConnection;
      final Batch batch = db.batch();
      for (final MealItem item in items) {
        batch.insert(
          MealItemModel.table,
          MealItemModel.toMap(item),
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> update(MealItem item) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        MealItemModel.table,
        MealItemModel.toMap(item),
        where: 'id = ?',
        whereArgs: <Object?>[item.id],
      );
    });
  }

  Future<List<MealItem>> getByMeal(int mealId) {
    return guard('get_by_meal', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        MealItemModel.table,
        where: 'meal_id = ?',
        whereArgs: <Object?>[mealId],
        orderBy: 'sort_order ASC',
      );
      return rows.map(MealItemModel.fromMap).toList();
    });
  }

  Future<void> deleteByMeal(int mealId) {
    return guard('delete_by_meal', () async {
      final Database db = await dbConnection;
      await db.delete(
        MealItemModel.table,
        where: 'meal_id = ?',
        whereArgs: <Object?>[mealId],
      );
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        MealItemModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
