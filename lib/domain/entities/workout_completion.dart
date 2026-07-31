import 'package:equatable/equatable.dart';

import 'achievement.dart';

/// Result captured when a workout session is finished.
class WorkoutCompletion extends Equatable {
  const WorkoutCompletion({
    required this.historyId,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.exercisesCompleted,
    required this.totalExercises,
    required this.completedAt,
    this.newAchievements = const <Achievement>[],
  });

  final int historyId;
  final int durationMinutes;
  final double caloriesBurned;
  final int exercisesCompleted;
  final int totalExercises;
  final DateTime completedAt;

  /// Achievements unlocked by this session.
  final List<Achievement> newAchievements;

  double get completionRatio =>
      totalExercises == 0 ? 0 : exercisesCompleted / totalExercises;

  @override
  List<Object?> get props => [
        historyId,
        durationMinutes,
        caloriesBurned,
        exercisesCompleted,
        totalExercises,
        completedAt,
        newAchievements,
      ];
}
