import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/workout_category.dart';
import '../../models/workout_category_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the global `workout_category` catalog.
class WorkoutCategoryLocalDataSource extends BaseLocalDataSource {
  WorkoutCategoryLocalDataSource({required super.database})
    : super(logName: 'WorkoutCategoryLocalDataSource');

  Future<int> insert(WorkoutCategory category) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        WorkoutCategoryModel.table,
        WorkoutCategoryModel.toMap(category),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });
  }

  Future<WorkoutCategory?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutCategoryModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return WorkoutCategoryModel.fromMap(rows.first);
    });
  }

  Future<WorkoutCategory?> getBySlug(String slug) {
    return guard('get_by_slug', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutCategoryModel.table,
        where: 'slug = ?',
        whereArgs: <Object?>[slug],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return WorkoutCategoryModel.fromMap(rows.first);
    });
  }

  Future<List<WorkoutCategory>> getAll() {
    return guard('get_all', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutCategoryModel.table,
        orderBy: 'sort_order ASC, id ASC',
      );
      return rows.map(WorkoutCategoryModel.fromMap).toList();
    });
  }
}
