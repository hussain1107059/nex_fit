import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../domain/entities/exercise_category.dart';
import '../../workout/widgets/workout_cover.dart';

/// Resolves a Material icon for an [ExerciseCategory].
IconData exerciseCategoryIconFor(ExerciseCategory? category) {
  return switch (category) {
    ExerciseCategory.chest => Icons.shield_rounded,
    ExerciseCategory.back => Icons.rowing_rounded,
    ExerciseCategory.shoulder => Icons.sports_handball_rounded,
    ExerciseCategory.arms => Icons.front_hand_rounded,
    ExerciseCategory.biceps => Icons.fitness_center_rounded,
    ExerciseCategory.triceps => Icons.sports_martial_arts_rounded,
    ExerciseCategory.legs => Icons.stairs_rounded,
    ExerciseCategory.core => Icons.donut_large_rounded,
    ExerciseCategory.abs => Icons.donut_large_rounded,
    ExerciseCategory.glutes => Icons.airline_seat_legroom_extra_rounded,
    ExerciseCategory.cardio => Icons.local_fire_department_rounded,
    ExerciseCategory.stretching => Icons.airline_seat_legroom_extra_rounded,
    ExerciseCategory.yoga => Icons.self_improvement_rounded,
    ExerciseCategory.fullBody => Icons.accessibility_new_rounded,
    null => Icons.fitness_center_rounded,
  };
}

/// Gradient cover used by exercise tiles when no image/GIF asset exists.
class ExerciseCover extends StatelessWidget {
  const ExerciseCover({
    super.key,
    this.category,
    this.name,
    this.width = double.infinity,
    this.height = 120,
    this.borderRadius,
    this.icon,
  });

  final ExerciseCategory? category;

  /// Exercise name — when provided, a keyword-matched icon wins over the
  /// generic category icon so each exercise reads distinctly.
  final String? name;
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
          icon ??
              workoutIconFromName(name) ??
              exerciseCategoryIconFor(category),
          size: height * 0.4,
          color: Color.alphaBlend(
            base.withValues(alpha: 0.72),
            context.colorScheme.surface,
          ).computeLuminance() > 0.5
              ? Colors.black87.withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}
