import 'package:equatable/equatable.dart';

import 'common_enums.dart';
import 'exercise_category.dart';

/// Combined criteria used to search and filter the exercise library.
class ExerciseFilter extends Equatable {
  const ExerciseFilter({
    this.query = '',
    this.category,
    this.difficulty,
    this.equipment,
    this.favoritesOnly = false,
  });

  final String query;
  final ExerciseCategory? category;
  final Difficulty? difficulty;
  final String? equipment;
  final bool favoritesOnly;

  bool get isEmpty =>
      query.trim().isEmpty &&
      category == null &&
      difficulty == null &&
      equipment == null &&
      !favoritesOnly;

  ExerciseFilter copyWith({
    String? query,
    ExerciseCategory? category,
    Difficulty? difficulty,
    String? equipment,
    bool? favoritesOnly,
  }) {
    return ExerciseFilter(
      query: query ?? this.query,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      equipment: equipment ?? this.equipment,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    );
  }

  @override
  List<Object?> get props => [
        query,
        category,
        difficulty,
        equipment,
        favoritesOnly,
      ];
}
