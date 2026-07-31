import 'package:equatable/equatable.dart';

/// Join row linking a [Workout] to one of its [Exercise]s with the number of
/// sets/reps, duration and rest time for that exercise.
class WorkoutExercise extends Equatable {
  const WorkoutExercise({
    this.id,
    required this.workoutId,
    required this.exerciseId,
    this.sets = 0,
    this.reps = 0,
    this.durationSeconds = 0,
    this.restSeconds = 0,
    this.sortOrder = 0,
  });

  final int? id;
  final int workoutId;
  final int exerciseId;
  final int sets;
  final int reps;
  final int durationSeconds;
  final int restSeconds;
  final int sortOrder;

  WorkoutExercise copyWith({
    int? id,
    int? workoutId,
    int? exerciseId,
    int? sets,
    int? reps,
    int? durationSeconds,
    int? restSeconds,
    int? sortOrder,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      exerciseId: exerciseId ?? this.exerciseId,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [
        id,
        workoutId,
        exerciseId,
        sets,
        reps,
        durationSeconds,
        restSeconds,
        sortOrder,
      ];
}
