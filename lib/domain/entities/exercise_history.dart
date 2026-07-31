import 'package:equatable/equatable.dart';

/// Per-exercise detail captured inside a workout history session.
class ExerciseHistory extends Equatable {
  const ExerciseHistory({
    this.id,
    required this.workoutHistoryId,
    this.exerciseId,
    this.sets = 0,
    this.reps = 0,
    this.weightKg,
    this.durationSeconds,
    this.completedAt,
  });

  final int? id;
  final int workoutHistoryId;
  final int? exerciseId;
  final int sets;
  final int reps;
  final double? weightKg;
  final int? durationSeconds;
  final DateTime? completedAt;

  ExerciseHistory copyWith({
    int? id,
    int? workoutHistoryId,
    int? exerciseId,
    int? sets,
    int? reps,
    double? weightKg,
    int? durationSeconds,
    DateTime? completedAt,
  }) {
    return ExerciseHistory(
      id: id ?? this.id,
      workoutHistoryId: workoutHistoryId ?? this.workoutHistoryId,
      exerciseId: exerciseId ?? this.exerciseId,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      weightKg: weightKg ?? this.weightKg,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        workoutHistoryId,
        exerciseId,
        sets,
        reps,
        weightKg,
        durationSeconds,
        completedAt,
      ];
}
