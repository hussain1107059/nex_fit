/// Muscle-group categories supported by the exercise library.
///
/// Persisted by their [ExerciseCategory.name] value on the `exercise` table.
enum ExerciseCategory {
  chest,
  back,
  shoulder,
  arms,
  biceps,
  triceps,
  legs,
  core,
  abs,
  glutes,
  cardio,
  stretching,
  yoga,
  fullBody;

  static ExerciseCategory fromName(String? value) {
    return ExerciseCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => ExerciseCategory.fullBody,
    );
  }

  /// Stable brand colour used by generated covers and chips.
  int get colorValue {
    return switch (this) {
      ExerciseCategory.chest => 0xFFE5484D,
      ExerciseCategory.back => 0xFF8B5CF6,
      ExerciseCategory.shoulder => 0xFF3B82F6,
      ExerciseCategory.arms => 0xFFF97316,
      ExerciseCategory.biceps => 0xFFF59E0B,
      ExerciseCategory.triceps => 0xFFEF4444,
      ExerciseCategory.legs => 0xFF10B981,
      ExerciseCategory.core => 0xFF06B6D4,
      ExerciseCategory.abs => 0xFF14B8A6,
      ExerciseCategory.glutes => 0xFFA855F7,
      ExerciseCategory.cardio => 0xFFEC4899,
      ExerciseCategory.stretching => 0xFF22C55E,
      ExerciseCategory.yoga => 0xFF6366F1,
      ExerciseCategory.fullBody => 0xFF0E9F6E,
    };
  }
}
