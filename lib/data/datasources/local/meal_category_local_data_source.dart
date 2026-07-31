import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/meal_category.dart';
import '../../models/meal_category_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the global `meal_category` catalog.
class MealCategoryLocalDataSource extends BaseLocalDataSource {
  MealCategoryLocalDataSource({required super.database})
    : super(logName: 'MealCategoryLocalDataSource');

  Future<int> insert(MealCategory category) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        MealCategoryModel.table,
        MealCategoryModel.toMap(category),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });
  }

  Future<MealCategory?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        MealCategoryModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return MealCategoryModel.fromMap(rows.first);
    });
  }

  Future<MealCategory?> getBySlug(String slug) {
    return guard('get_by_slug', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        MealCategoryModel.table,
        where: 'slug = ?',
        whereArgs: <Object?>[slug],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return MealCategoryModel.fromMap(rows.first);
    });
  }

  Future<List<MealCategory>> getAll() {
    return guard('get_all', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        MealCategoryModel.table,
        orderBy: 'sort_order ASC, id ASC',
      );
      return rows.map(MealCategoryModel.fromMap).toList();
    });
  }
}
