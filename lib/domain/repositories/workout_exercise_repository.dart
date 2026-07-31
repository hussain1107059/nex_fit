import '../entities/workout_exercise.dart';
import '../entities/workout_exercise_detail.dart';

/// Contract for the workout <-> exercise join rows.
abstract interface class WorkoutExerciseRepository {
  Future<int> insert(WorkoutExercise workoutExercise);

  Future<void> update(WorkoutExercise workoutExercise);

  Future<WorkoutExercise?> getById(int id);

  Future<List<WorkoutExercise>> getByWorkout(int workoutId);

  Future<List<WorkoutExerciseDetail>> getDetailsByWorkout(int workoutId);

  Future<Map<int, List<WorkoutExerciseDetail>>> getDetailsByWorkouts(
    List<int> workoutIds,
  );

  Future<void> delete(int id);

  Future<void> deleteByWorkout(int workoutId);
}
