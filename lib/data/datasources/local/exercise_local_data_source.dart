import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/exercise.dart';
import '../../models/exercise_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `exercise` table (built-in + user exercises).
class ExerciseLocalDataSource extends BaseLocalDataSource {
  ExerciseLocalDataSource({required super.database})
    : super(logName: 'ExerciseLocalDataSource');

  Future<int> insert(Exercise exercise) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        ExerciseModel.table,
        ExerciseModel.toMap(exercise),
      );
    });
  }

  Future<void> update(Exercise exercise) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        ExerciseModel.table,
        ExerciseModel.toMap(exercise),
        where: 'id = ?',
        whereArgs: <Object?>[exercise.id],
      );
    });
  }

  Future<Exercise?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ExerciseModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ExerciseModel.fromMap(rows.first);
    });
  }

  Future<List<Exercise>> getBuiltIn() {
    return guard('get_built_in', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ExerciseModel.table,
        where: 'user_id IS NULL',
        orderBy: 'name ASC',
      );
      return rows.map(ExerciseModel.fromMap).toList();
    });
  }

  Future<List<Exercise>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ExerciseModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'name ASC',
      );
      return rows.map(ExerciseModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        ExerciseModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
