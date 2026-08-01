import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../domain/entities/exercise_category.dart';

/// Resolves a Material icon for an [ExerciseCategory].
IconData exerciseCategoryIconFor(ExerciseCategory? category) {
  return switch (category) {
    ExerciseCategory.chest => Icons.fitness_center_rounded,
    ExerciseCategory.back => Icons.fitness_center_rounded,
    ExerciseCategory.shoulder => Icons.accessibility_new_rounded,
    ExerciseCategory.arms => Icons.sports_martial_arts_rounded,
    ExerciseCategory.biceps => Icons.sports_martial_arts_rounded,
    ExerciseCategory.triceps => Icons.sports_martial_arts_rounded,
    ExerciseCategory.legs => Icons.directions_run_rounded,
    ExerciseCategory.core => Icons.accessibility_new_rounded,
    ExerciseCategory.abs => Icons.self_improvement_rounded,
    ExerciseCategory.glutes => Icons.airline_seat_legroom_extra_rounded,
    ExerciseCategory.cardio => Icons.local_fire_department_rounded,
    ExerciseCategory.stretching => Icons.airline_seat_legroom_extra_rounded,
    ExerciseCategory.yoga => Icons.self_improvement_rounded,
    ExerciseCategory.fullBody => Icons.fitness_center_rounded,
    null => Icons.fitness_center_rounded,
  };
}

/// Gradient cover used by exercise tiles when no image/GIF asset exists.
class ExerciseCover extends StatelessWidget {
  const ExerciseCover({
    super.key,
    this.category,
    this.width = double.infinity,
    this.height = 120,
    this.borderRadius,
    this.icon,
  });

  final ExerciseCategory? category;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color base = Color(category?.colorValue ?? 0xFF0E9F6E);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? AppRadius.mdRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            base.withValues(alpha: 0.92),
            base.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon ?? exerciseCategoryIconFor(category),
          size: height * 0.4,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}
