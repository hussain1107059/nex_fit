import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radius.dart';

/// Resolves a Material icon name (from the category catalog) into [IconData].
IconData categoryIconFor(
  String? iconName, {
  IconData fallback = Icons.fitness_center_rounded,
}) {
  if (iconName == null || iconName.isEmpty) return fallback;
  return switch (iconName) {
    'home' || 'home_workout' => Icons.home_rounded,
    'fitness_center' => Icons.fitness_center_rounded,
    'directions_run' || 'running' => Icons.directions_run_rounded,
    'self_improvement' || 'yoga' => Icons.self_improvement_rounded,
    'accessibility_new' => Icons.accessibility_new_rounded,
    'sports_gymnastics' => Icons.sports_gymnastics_rounded,
    'health_and_safety' => Icons.health_and_safety_rounded,
    'sports_martial_arts' => Icons.sports_martial_arts_rounded,
    'airline_seat_flat' ||
    'stretching' => Icons.airline_seat_legroom_extra_rounded,
    'bolt' || 'hiit' => Icons.bolt_rounded,
    'local_fire_department' || 'cardio' => Icons.local_fire_department_rounded,
    'sports' => Icons.sports_rounded,
    'scale' || 'weight' => Icons.scale_rounded,
    'fitness_center_rounded' => Icons.fitness_center_rounded,
    _ => fallback,
  };
}

/// Gradient cover used by workout and category tiles when no image exists.
class WorkoutCover extends StatelessWidget {
  const WorkoutCover({
    super.key,
    this.colorValue,
    this.label,
    this.icon,
    this.width = double.infinity,
    this.height = 120,
    this.borderRadius,
  });

  final int? colorValue;
  final String? label;
  final IconData? icon;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final Color base = colorValue != null
        ? Color(colorValue!)
        : context.colorScheme.primary;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? AppRadius.mdRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            base.withValues(alpha: 0.9),
            base.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: height * 0.4,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
