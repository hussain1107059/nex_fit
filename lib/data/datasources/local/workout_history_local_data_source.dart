import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/workout_history.dart';
import '../../models/model_codec.dart';
import '../../models/workout_history_model.dart';
import 'base_local_data_source.dart';

/// SQLite data source for the `workout_history` table.
class WorkoutHistoryLocalDataSource extends BaseLocalDataSource {
  WorkoutHistoryLocalDataSource({required super.database})
    : super(logName: 'WorkoutHistoryLocalDataSource');

  Future<int> insert(WorkoutHistory history) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.insert(
        WorkoutHistoryModel.table,
        WorkoutHistoryModel.toMap(history),
      );
    });
  }

  Future<void> update(WorkoutHistory history) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.update(
        WorkoutHistoryModel.table,
        WorkoutHistoryModel.toMap(history),
        where: 'id = ?',
        whereArgs: <Object?>[history.id],
      );
    });
  }

  Future<WorkoutHistory?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutHistoryModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return WorkoutHistoryModel.fromMap(rows.first);
    });
  }

  Future<List<WorkoutHistory>> getByUserId(String userId) {
    return guard('get_by_user_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutHistoryModel.table,
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'started_at DESC',
      );
      return rows.map(WorkoutHistoryModel.fromMap).toList();
    });
  }

  Future<List<WorkoutHistory>> getCompleted(String userId) {
    return guard('get_completed', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutHistoryModel.table,
        where: 'user_id = ? AND is_completed = 1',
        whereArgs: <Object?>[userId],
        orderBy: 'ended_at DESC',
      );
      return rows.map(WorkoutHistoryModel.fromMap).toList();
    });
  }

  /// The most recent in-progress (incomplete) session for a user.
  Future<WorkoutHistory?> getInProgress(String userId) {
    return guard('get_in_progress', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutHistoryModel.table,
        where: 'user_id = ? AND is_completed = 0',
        whereArgs: <Object?>[userId],
        orderBy: 'started_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return WorkoutHistoryModel.fromMap(rows.first);
    });
  }

  /// Workout ids of the most recently completed sessions, newest first.
  Future<List<int>> getRecentWorkoutIds(String userId, {int limit = 10}) {
    return guard('get_recent_workout_ids', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT workout_id FROM ${WorkoutHistoryModel.table} '
        'WHERE user_id = ? AND is_completed = 1 AND workout_id IS NOT NULL '
        'GROUP BY workout_id ORDER BY MAX(started_at) DESC LIMIT ?',
        <Object?>[userId, limit],
      );
      return rows
          .map((Map<String, Object?> row) => row['workout_id'] as int)
          .toList();
    });
  }

  /// Workout ids ranked by how often they have been completed.
  Future<List<int>> getPopularWorkoutIds(String userId, {int limit = 10}) {
    return guard('get_popular_workout_ids', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT workout_id, COUNT(*) AS completed_count '
        'FROM ${WorkoutHistoryModel.table} '
        'WHERE user_id = ? AND is_completed = 1 AND workout_id IS NOT NULL '
        'GROUP BY workout_id ORDER BY completed_count DESC, MAX(started_at) DESC '
        'LIMIT ?',
        <Object?>[userId, limit],
      );
      return rows
          .map((Map<String, Object?> row) => row['workout_id'] as int)
          .toList();
    });
  }

  Future<int> countCompleted(String userId) {
    return guard('count_completed', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM ${WorkoutHistoryModel.table} '
        'WHERE user_id = ? AND is_completed = 1',
        <Object?>[userId],
      );
      return rows.first['count'] as int? ?? 0;
    });
  }

  Future<DateTime?> getLastCompletedDate(String userId) {
    return guard('get_last_completed_date', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT ended_at FROM ${WorkoutHistoryModel.table} '
        'WHERE user_id = ? AND is_completed = 1 '
        'ORDER BY ended_at DESC LIMIT 1',
        <Object?>[userId],
      );
      if (rows.isEmpty) return null;
      return ModelCodec.fromEpochMs(rows.first['ended_at'] as int?);
    });
  }

  Future<double> getTotalCaloriesBurned(String userId) {
    return guard('get_total_calories', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT SUM(calories_burn) AS total FROM ${WorkoutHistoryModel.table} '
        'WHERE user_id = ? AND is_completed = 1',
        <Object?>[userId],
      );
      return ModelCodec.toDouble(rows.first['total']) ?? 0;
    });
  }

  Future<List<WorkoutHistory>> getByDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return guard('get_by_date_range', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutHistoryModel.table,
        where: 'user_id = ? AND started_at >= ? AND started_at < ?',
        whereArgs: <Object?>[
          userId,
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ],
        orderBy: 'started_at DESC',
      );
      return rows.map(WorkoutHistoryModel.fromMap).toList();
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.delete(
        WorkoutHistoryModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }
}
