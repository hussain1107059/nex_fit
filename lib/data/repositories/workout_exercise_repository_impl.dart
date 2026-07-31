import '../../domain/entities/workout_exercise.dart';
import '../../domain/entities/workout_exercise_detail.dart';
import '../../domain/repositories/workout_exercise_repository.dart';
import '../datasources/local/workout_exercise_local_data_source.dart';

/// SQLite backed implementation of [WorkoutExerciseRepository].
class WorkoutExerciseRepositoryImpl implements WorkoutExerciseRepository {
  const WorkoutExerciseRepositoryImpl(this._dataSource);

  final WorkoutExerciseLocalDataSource _dataSource;

  @override
  Future<int> insert(WorkoutExercise workoutExercise) =>
      _dataSource.insert(workoutExercise);

  @override
  Future<void> update(WorkoutExercise workoutExercise) =>
      _dataSource.update(workoutExercise);

  @override
  Future<WorkoutExercise?> getById(int id) => _dataSource.getById(id);

  @override
  Future<List<WorkoutExercise>> getByWorkout(int workoutId) =>
      _dataSource.getByWorkout(workoutId);

  @override
  Future<List<WorkoutExerciseDetail>> getDetailsByWorkout(int workoutId) =>
      _dataSource.getDetailsByWorkout(workoutId);

  @override
  Future<Map<int, List<WorkoutExerciseDetail>>> getDetailsByWorkouts(
    List<int> workoutIds,
  ) => _dataSource.getDetailsByWorkouts(workoutIds);

  @override
  Future<void> delete(int id) => _dataSource.delete(id);

  @override
  Future<void> deleteByWorkout(int workoutId) =>
      _dataSource.deleteByWorkout(workoutId);
}
