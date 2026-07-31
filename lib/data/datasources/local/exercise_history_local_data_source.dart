import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/exercise_history.dart';
import '../../models/exercise_history_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `exercise_history` table.
class ExerciseHistoryLocalDataSource extends BaseLocalDataSource {
  ExerciseHistoryLocalDataSource({required super.database})
    : super(logName: 'ExerciseHistoryLocalDataSource');

  Future<int> insert(ExerciseHistory history) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        ExerciseHistoryModel.table,
        ExerciseHistoryModel.toMap(history),
      );
    });
  }

  Future<void> update(ExerciseHistory history) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        ExerciseHistoryModel.table,
        ExerciseHistoryModel.toMap(history),
        where: 'id = ?',
        whereArgs: <Object?>[history.id],
      );
    });
  }

  Future<ExerciseHistory?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ExerciseHistoryModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return ExerciseHistoryModel.fromMap(rows.first);
    });
  }

  Future<List<ExerciseHistory>> getByWorkoutHistory(int workoutHistoryId) {
    return guard('get_by_workout_history', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        ExerciseHistoryModel.table,
        where: 'workout_history_id = ?',
        whereArgs: <Object?>[workoutHistoryId],
        orderBy: 'id ASC',
      );
      return rows.map(ExerciseHistoryModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        ExerciseHistoryModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
