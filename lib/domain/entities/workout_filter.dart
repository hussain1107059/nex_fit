import 'package:equatable/equatable.dart';

import 'common_enums.dart';

/// Duration band used by the filter chips.
enum WorkoutDurationFilter {
  any,
  short,
  medium,
  long;

  static WorkoutDurationFilter fromName(String? value) {
    return WorkoutDurationFilter.values.firstWhere(
      (filter) => filter.name == value,
      orElse: () => WorkoutDurationFilter.any,
    );
  }
}

/// Combined criteria used to search and filter the workout library.
class WorkoutFilter extends Equatable {
  const WorkoutFilter({
    this.query = '',
    this.difficulty,
    this.duration = WorkoutDurationFilter.any,
    this.equipment,
    this.goal,
    this.categorySlug,
  });

  final String query;
  final Difficulty? difficulty;
  final WorkoutDurationFilter duration;

  /// Equipment name, e.g. "Dumbbell" or "None".
  final String? equipment;

  /// Fitness goal slug (weight_loss, muscle_gain, ...) or null.
  final String? goal;

  /// Category slug or null.
  final String? categorySlug;

  bool get isEmpty =>
      query.trim().isEmpty &&
      difficulty == null &&
      duration == WorkoutDurationFilter.any &&
      equipment == null &&
      goal == null &&
      categorySlug == null;

  WorkoutFilter copyWith({
    String? query,
    Difficulty? difficulty,
    WorkoutDurationFilter? duration,
    String? equipment,
    String? goal,
    String? categorySlug,
  }) {
    return WorkoutFilter(
      query: query ?? this.query,
      difficulty: difficulty ?? this.difficulty,
      duration: duration ?? this.duration,
      equipment: equipment ?? this.equipment,
      goal: goal ?? this.goal,
      categorySlug: categorySlug ?? this.categorySlug,
    );
  }

  @override
  List<Object?> get props => [
        query,
        difficulty,
        duration,
        equipment,
        goal,
        categorySlug,
      ];
}
