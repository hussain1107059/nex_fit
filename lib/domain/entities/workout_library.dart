import 'package:equatable/equatable.dart';

import 'workout.dart';
import 'workout_category.dart';

/// The in-progress session a user can resume from the home screen.
class ContinueWorkout extends Equatable {
  const ContinueWorkout({
    required this.workout,
    required this.historyId,
    required this.startedAt,
    this.completedExercises = 0,
    this.totalExercises = 0,
  });

  final Workout workout;
  final int historyId;
  final DateTime startedAt;
  final int completedExercises;
  final int totalExercises;

  double get progress =>
      totalExercises == 0 ? 0 : completedExercises / totalExercises;

  @override
  List<Object?> get props => [
        workout,
        historyId,
        startedAt,
        completedExercises,
        totalExercises,
      ];
}

/// Aggregate loaded for the workout home tab.
class WorkoutLibraryData extends Equatable {
  const WorkoutLibraryData({
    this.categories = const <WorkoutCategory>[],
    this.recommended = const <Workout>[],
    this.popular = const <Workout>[],
    this.recent = const <Workout>[],
    this.continueWorkout,
    this.favorites = const <Workout>[],
  });

  final List<WorkoutCategory> categories;
  final List<Workout> recommended;
  final List<Workout> popular;
  final List<Workout> recent;
  final ContinueWorkout? continueWorkout;
  final List<Workout> favorites;

  WorkoutLibraryData copyWith({
    List<WorkoutCategory>? categories,
    List<Workout>? recommended,
    List<Workout>? popular,
    List<Workout>? recent,
    ContinueWorkout? continueWorkout,
    List<Workout>? favorites,
  }) {
    return WorkoutLibraryData(
      categories: categories ?? this.categories,
      recommended: recommended ?? this.recommended,
      popular: popular ?? this.popular,
      recent: recent ?? this.recent,
      continueWorkout: continueWorkout ?? this.continueWorkout,
      favorites: favorites ?? this.favorites,
    );
  }

  @override
  List<Object?> get props => [
        categories,
        recommended,
        popular,
        recent,
        continueWorkout,
        favorites,
      ];
}
