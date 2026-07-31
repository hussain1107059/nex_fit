import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/workout.dart';
import '../../models/workout_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `workout` table.
class WorkoutLocalDataSource extends BaseLocalDataSource {
  WorkoutLocalDataSource({required super.database})
    : super(logName: 'WorkoutLocalDataSource');

  Future<int> insert(Workout workout) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        WorkoutModel.table,
        WorkoutModel.toMap(workout),
      );
    });
  }

  Future<void> update(Workout workout) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        WorkoutModel.table,
        WorkoutModel.toMap(workout),
        where: 'id = ?',
        whereArgs: <Object?>[workout.id],
      );
    });
  }

  Future<Workout?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return WorkoutModel.fromMap(rows.first);
    });
  }

  Future<List<Workout>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'updated_at DESC',
      );
      return rows.map(WorkoutModel.fromMap).toList();
    });
  }

  Future<List<Workout>> getByCategory(int categoryId) {
    return guard('get_by_category', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutModel.table,
        where: 'category_id = ?',
        whereArgs: <Object?>[categoryId],
        orderBy: 'name ASC',
      );
      return rows.map(WorkoutModel.fromMap).toList();
    });
  }

  Future<List<Workout>> getByCategoryForUser(
    String userId,
    int categoryId,
  ) {
    return guard('get_by_category_for_user', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutModel.table,
        where: 'user_id = ? AND category_id = ?',
        whereArgs: <Object?>[userId, categoryId],
        orderBy: 'name ASC',
      );
      return rows.map(WorkoutModel.fromMap).toList();
    });
  }

  Future<List<Workout>> getFavorites(String userId) {
    return guard('get_favorites', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutModel.table,
        where: 'user_id = ? AND is_favorite = 1',
        whereArgs: <Object?>[userId],
        orderBy: 'updated_at DESC',
      );
      return rows.map(WorkoutModel.fromMap).toList();
    });
  }

  Future<List<Workout>> getByIds(List<int> ids) {
    return guard('get_by_ids', () async {
      if (ids.isEmpty) return const <Workout>[];
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutModel.table,
        where: 'id IN (${List<String>.filled(ids.length, '?').join(', ')})',
        whereArgs: ids,
      );
      return rows.map(WorkoutModel.fromMap).toList();
    });
  }

  Future<int> countByUser(String userId) {
    return guard('count_by_user', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM ${WorkoutModel.table} '
        'WHERE user_id = ?',
        <Object?>[userId],
      );
      return rows.first['count'] as int? ?? 0;
    });
  }

  Future<int> countBuiltInByUser(String userId) {
    return guard('count_built_in', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM ${WorkoutModel.table} '
        'WHERE user_id = ? AND is_custom = 0',
        <Object?>[userId],
      );
      return rows.first['count'] as int? ?? 0;
    });
  }

  Future<void> setFavorite(int id, bool favorite) {
    return guard('set_favorite', () async {
      final Database db = await dbConnection;
      await db.update(
        WorkoutModel.table,
        <String, Object?>{'is_favorite': favorite ? 1 : 0},
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        WorkoutModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
