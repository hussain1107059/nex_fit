import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/workout_exercise.dart';
import '../../../domain/entities/workout_exercise_detail.dart';
import '../../models/exercise_model.dart';
import '../../models/workout_exercise_model.dart';
import '../../models/workout_model.dart';
import 'base_local_data_source.dart';
import 'syncable_dao.dart';

/// SQLite data source for the `workout_exercise` join table.
///
/// Sync-aware (PROMPT 11 Batch 1). This is a child table: it has no `user_id`
/// on its entity, so the DAO resolves ownership from the owning `workout` row.
/// If the parent workout is not present yet the join row is stored without a
/// sync event (it becomes syncable once the parent flow re-inserts it, which
/// never happens in practice because workouts are written before their
/// exercises).
class WorkoutExerciseLocalDataSource extends BaseLocalDataSource {
  WorkoutExerciseLocalDataSource({required super.database})
    : super(logName: 'WorkoutExerciseLocalDataSource');

  Future<int> insert(WorkoutExercise workoutExercise) {
    return guard('insert', () async {
      final Database db = await dbConnection;
      return db.transaction((Transaction txn) async {
        final int now = SyncableDao.nowMs();
        final Map<String, Object?> values =
            WorkoutExerciseModel.toMap(workoutExercise);
        values['uuid'] = SyncableDao.newUuid();
        values['created_at'] = now;
        values['updated_at'] = now;
        values['row_version'] = SyncableDao.firstRowVersion;
        final String? userId = await _userIdForWorkout(
          txn,
          workoutExercise.workoutId,
        );
        if (userId != null) values['user_id'] = userId;
        final int id = await txn.insert(WorkoutExerciseModel.table, values);
        if (userId != null) {
          await SyncableDao.recordCreate(
            txn,
            entity: WorkoutExerciseModel.table,
            entityId: '$id',
            userId: userId,
          );
        }
        return id;
      });
    });
  }

  Future<void> update(WorkoutExercise workoutExercise) {
    return guard('update', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing =
            await _findRow(txn, workoutExercise.id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        final Map<String, Object?> values =
            WorkoutExerciseModel.toMap(workoutExercise);
        values['uuid'] = existing['uuid'] as String;
        values['updated_at'] = now;
        values['row_version'] = baseVersion + 1;
        await txn.update(
          WorkoutExerciseModel.table,
          values,
          where: 'id = ?',
          whereArgs: <Object?>[workoutExercise.id],
        );
        final String? userId = existing['user_id'] as String?;
        if (userId != null) {
          await SyncableDao.recordUpdate(
            txn,
            entity: WorkoutExerciseModel.table,
            entityId: '${workoutExercise.id}',
            userId: userId,
            baseVersion: baseVersion,
          );
        }
      });
    });
  }

  Future<WorkoutExercise?> getById(int id) {
    return guard('get_by_id', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutExerciseModel.table,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return WorkoutExerciseModel.fromMap(rows.first);
    });
  }

  Future<List<WorkoutExercise>> getByWorkout(int workoutId) {
    return guard('get_by_workout', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.query(
        WorkoutExerciseModel.table,
        where: 'workout_id = ? AND deleted_at IS NULL',
        whereArgs: <Object?>[workoutId],
        orderBy: 'sort_order ASC, id ASC',
      );
      return rows.map(WorkoutExerciseModel.fromMap).toList();
    });
  }

  /// All join rows for [workoutId] joined with their exercise payload.
  Future<List<WorkoutExerciseDetail>> getDetailsByWorkout(int workoutId) {
    return guard('get_details_by_workout', () async {
      final Database db = await dbConnection;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        '$_joinSelect WHERE we.workout_id = ? AND we.deleted_at IS NULL '
        'ORDER BY we.sort_order ASC, we.id ASC',
        <Object?>[workoutId],
      );
      return rows.map(_fromJoinedRow).toList();
    });
  }

  /// Join rows for several workouts in a single query, grouped by workout.
  Future<Map<int, List<WorkoutExerciseDetail>>> getDetailsByWorkouts(
    List<int> workoutIds,
  ) {
    return guard('get_details_by_workouts', () async {
      if (workoutIds.isEmpty) return const <int, List<WorkoutExerciseDetail>>{};
      final Database db = await dbConnection;
      final String placeholders = List<String>.filled(
        workoutIds.length,
        '?',
      ).join(', ');
      final List<Map<String, Object?>> rows = await db.rawQuery(
        '$_joinSelect WHERE we.workout_id IN ($placeholders) '
        'AND we.deleted_at IS NULL '
        'ORDER BY we.workout_id ASC, we.sort_order ASC, we.id ASC',
        workoutIds,
      );

      final Map<int, List<WorkoutExerciseDetail>> result =
          <int, List<WorkoutExerciseDetail>>{};
      for (final Map<String, Object?> row in rows) {
        final WorkoutExerciseDetail detail = _fromJoinedRow(row);
        result
            .putIfAbsent(
              detail.workoutExercise.workoutId,
              () => <WorkoutExerciseDetail>[],
            )
            .add(detail);
      }
      return result;
    });
  }

  Future<void> delete(int id) {
    return guard('delete', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final Map<String, Object?>? existing = await _findRow(txn, id);
        if (existing == null) return;
        final int now = SyncableDao.nowMs();
        final int baseVersion = _version(existing);
        await _softDelete(txn, id, now: now, baseVersion: baseVersion);
        final String? userId = existing['user_id'] as String?;
        if (userId != null) {
          await SyncableDao.recordDelete(
            txn,
            entity: WorkoutExerciseModel.table,
            entityId: '$id',
            userId: userId,
            baseVersion: baseVersion,
          );
        }
      });
    });
  }

  Future<void> deleteByWorkout(int workoutId) {
    return guard('delete_by_workout', () async {
      final Database db = await dbConnection;
      await db.transaction((Transaction txn) async {
        final String? userId = await _userIdForWorkout(txn, workoutId);
        final List<Map<String, Object?>> rows = await txn.query(
          WorkoutExerciseModel.table,
          columns: const <String>['id', 'row_version'],
          where: 'workout_id = ? AND deleted_at IS NULL',
          whereArgs: <Object?>[workoutId],
        );
        final int now = SyncableDao.nowMs();
        for (final Map<String, Object?> row in rows) {
          final int id = row['id'] as int;
          final int baseVersion = _version(row);
          await _softDelete(txn, id, now: now, baseVersion: baseVersion);
          if (userId != null) {
            await SyncableDao.recordDelete(
              txn,
              entity: WorkoutExerciseModel.table,
              entityId: '$id',
              userId: userId,
              baseVersion: baseVersion,
            );
          }
        }
      });
    });
  }

  Future<Map<String, Object?>?> _findRow(Transaction txn, int? id) async {
    if (id == null) return null;
    final List<Map<String, Object?>> rows = await txn.query(
      WorkoutExerciseModel.table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<String?> _userIdForWorkout(Transaction txn, int workoutId) async {
    final List<Map<String, Object?>> rows = await txn.query(
      WorkoutModel.table,
      columns: const <String>['user_id'],
      where: 'id = ?',
      whereArgs: <Object?>[workoutId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['user_id'] as String?;
  }

  Future<void> _softDelete(
    Transaction txn,
    int id, {
    required int now,
    required int baseVersion,
  }) async {
    await txn.update(
      WorkoutExerciseModel.table,
      <String, Object?>{
        'deleted_at': now,
        'updated_at': now,
        'row_version': baseVersion + 1,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  static int _version(Map<String, Object?> row) =>
      (row['row_version'] as num?)?.toInt() ?? 0;

  static const String _joinSelect = '''
    SELECT
      we.id, we.workout_id, we.exercise_id, we.sets, we.reps,
      we.duration_seconds, we.rest_seconds, we.sort_order,
      e.id AS ex_id, e.user_id AS ex_user_id, e.name AS ex_name,
      e.scientific_name AS ex_scientific_name,
      e.description AS ex_description, e.instructions AS ex_instructions,
      e.body_part AS ex_body_part, e.secondary_muscle AS ex_secondary_muscle,
      e.equipment AS ex_equipment, e.difficulty AS ex_difficulty,
      e.category AS ex_category, e.image AS ex_image, e.gif_path AS ex_gif_path,
      e.calories_per_minute AS ex_calories_per_minute,
      e.estimated_calories AS ex_estimated_calories,
      e.duration_seconds AS ex_duration_seconds, e.sets AS ex_sets,
      e.reps AS ex_reps, e.rest_seconds AS ex_rest_seconds,
      e.tips AS ex_tips, e.common_mistakes AS ex_common_mistakes,
      e.safety_instructions AS ex_safety_instructions,
      e.is_custom AS ex_is_custom, e.created_at AS ex_created_at
    FROM ${WorkoutExerciseModel.table} we
    JOIN ${ExerciseModel.table} e ON e.id = we.exercise_id
  ''';

  WorkoutExerciseDetail _fromJoinedRow(Map<String, Object?> row) {
    final WorkoutExercise join = WorkoutExerciseModel.fromMap(row);
    final Exercise exercise = ExerciseModel.fromMap(_exerciseColumns(row));
    return WorkoutExerciseDetail(workoutExercise: join, exercise: exercise);
  }

  Map<String, Object?> _exerciseColumns(Map<String, Object?> row) {
    return <String, Object?>{
      'id': row['ex_id'],
      'user_id': row['ex_user_id'],
      'name': row['ex_name'],
      'scientific_name': row['ex_scientific_name'],
      'description': row['ex_description'],
      'instructions': row['ex_instructions'],
      'body_part': row['ex_body_part'],
      'secondary_muscle': row['ex_secondary_muscle'],
      'equipment': row['ex_equipment'],
      'difficulty': row['ex_difficulty'],
      'category': row['ex_category'],
      'image': row['ex_image'],
      'gif_path': row['ex_gif_path'],
      'calories_per_minute': row['ex_calories_per_minute'],
      'estimated_calories': row['ex_estimated_calories'],
      'duration_seconds': row['ex_duration_seconds'],
      'sets': row['ex_sets'],
      'reps': row['ex_reps'],
      'rest_seconds': row['ex_rest_seconds'],
      'tips': row['ex_tips'],
      'common_mistakes': row['ex_common_mistakes'],
      'safety_instructions': row['ex_safety_instructions'],
      'is_custom': row['ex_is_custom'],
      'created_at': row['ex_created_at'],
    };
  }
}