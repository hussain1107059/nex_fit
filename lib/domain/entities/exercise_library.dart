import 'package:equatable/equatable.dart';

import 'exercise.dart';
import 'exercise_category.dart';

/// Aggregate loaded for the exercise library screen.
class ExerciseLibraryData extends Equatable {
  const ExerciseLibraryData({
    this.exercises = const <Exercise>[],
    this.favorites = const <Exercise>[],
  });

  final List<Exercise> exercises;
  final List<Exercise> favorites;

  List<ExerciseCategory> get categories => ExerciseCategory.values;

  int get totalExercises => exercises.length;

  int get favoritesCount => favorites.length;

  @override
  List<Object?> get props => [exercises, favorites];
}
