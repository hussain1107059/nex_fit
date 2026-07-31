import 'package:equatable/equatable.dart';

import 'exercise.dart';
import 'workout_exercise.dart';

/// A [WorkoutExercise] join row enriched with its full [Exercise] payload.
class WorkoutExerciseDetail extends Equatable {
  const WorkoutExerciseDetail({
    required this.exercise,
    required this.workoutExercise,
  });

  final Exercise exercise;
  final WorkoutExercise workoutExercise;

  int get sets => workoutExercise.sets;
  int get reps => workoutExercise.reps;
  int get durationSeconds => workoutExercise.durationSeconds;
  int get restSeconds => workoutExercise.restSeconds;
  int get sortOrder => workoutExercise.sortOrder;

  /// Estimated energy cost of one round of this exercise (kcal).
  double get estimatedCalories {
    final double? perMinute = exercise.caloriesPerMinute;
    if (perMinute == null || perMinute <= 0) return 0;
    final int seconds = durationSeconds > 0 ? durationSeconds : 30;
    return perMinute * seconds / 60;
  }

  @override
  List<Object?> get props => [exercise, workoutExercise];
}
