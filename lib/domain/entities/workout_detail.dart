import 'package:equatable/equatable.dart';

import 'workout.dart';
import 'workout_category.dart';
import 'workout_exercise_detail.dart';

/// A workout enriched with its category and ordered exercise list.
class WorkoutDetail extends Equatable {
  const WorkoutDetail({
    required this.workout,
    this.category,
    this.exercises = const <WorkoutExerciseDetail>[],
  });

  final Workout workout;
  final WorkoutCategory? category;
  final List<WorkoutExerciseDetail> exercises;

  int get exerciseCount => exercises.length;

  /// Total planned time (active + rest) in seconds.
  int get totalSeconds => exercises.fold<int>(
        0,
        (int sum, WorkoutExerciseDetail detail) =>
            sum + detail.durationSeconds + detail.restSeconds,
      );

  int get totalDurationMinutes {
    final int minutes = (totalSeconds / 60).ceil();
    return minutes > 0 ? minutes : workout.durationMinutes ?? 0;
  }

  /// Equipment set across every exercise, deduplicated and ordered.
  List<String> get equipment {
    final Set<String> result = <String>{};
    for (final WorkoutExerciseDetail detail in exercises) {
      final String? value = detail.exercise.equipment;
      if (value != null && value.isNotEmpty) result.add(value);
    }
    return result.toList(growable: false);
  }

  /// Target muscle groups across every exercise, deduplicated and ordered.
  List<String> get targetMuscles {
    final Set<String> result = <String>{};
    for (final WorkoutExerciseDetail detail in exercises) {
      final String? value = detail.exercise.bodyPart;
      if (value != null && value.isNotEmpty) result.add(value);
    }
    return result.toList(growable: false);
  }

  /// Estimated calories for one full pass of the routine.
  double get estimatedCalories {
    final double total = exercises.fold<double>(
      0,
      (double sum, WorkoutExerciseDetail detail) =>
          sum + detail.estimatedCalories,
    );
    return total > 0
        ? total
        : (workout.caloriesBurn ?? totalDurationMinutes * 6);
  }

  @override
  List<Object?> get props => [workout, category, exercises];
}
