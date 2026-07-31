import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../domain/entities/common_enums.dart';
import '../../../../domain/entities/workout.dart';
import '../../../../domain/entities/workout_category.dart';
import '../../../../l10n/app_localizations.dart';
import 'workout_cover.dart';

/// Localised label for a [Difficulty] value.
String difficultyLabel(BuildContext context, Difficulty? difficulty) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  return switch (difficulty) {
    Difficulty.beginner => l10n.workoutDifficultyBeginner,
    Difficulty.intermediate => l10n.workoutDifficultyIntermediate,
    Difficulty.advanced => l10n.workoutDifficultyAdvanced,
    null => '',
  };
}

/// Compact duration label, e.g. "20 min".
String workoutDurationLabel(BuildContext context, int? minutes) {
  return minutes == null
      ? '–'
      : '${minutes.toString().toBanglaDigits()} ${context.l10n.dashboardMinutesShort}';
}

/// Small coloured chip that communicates workout difficulty.
class DifficultyChip extends StatelessWidget {
  const DifficultyChip({super.key, required this.difficulty});

  final Difficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (difficulty) {
      Difficulty.beginner => context.colorScheme.secondary,
      Difficulty.intermediate => context.colorScheme.tertiary,
      Difficulty.advanced => context.colorScheme.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: AppRadius.pillRadius,
        color: color.withValues(alpha: 0.14),
      ),
      child: Text(
        difficultyLabel(context, difficulty),
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Horizontal card showing a single workout.
class WorkoutCard extends StatelessWidget {
  const WorkoutCard({
    super.key,
    required this.workout,
    this.category,
    required this.onTap,
    this.onFavorite,
    this.margin,
  });

  final Workout workout;
  final WorkoutCategory? category;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppCard(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadius.mdRadius,
              child: SizedBox(
                width: 84,
                height: 84,
                child: WorkoutCover(
                  colorValue: category?.color,
                  icon: categoryIconFor(category?.icon),
                ),
              ),
            ),
            AppSpacing.md.widthSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    workout.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (workout.difficulty != null) ...[
                    const SizedBox(height: 4),
                    DifficultyChip(difficulty: workout.difficulty!),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      4.widthSpace,
                      Text(
                        workoutDurationLabel(context, workout.durationMinutes),
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      12.widthSpace,
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 14,
                        color: context.colorScheme.tertiary,
                      ),
                      4.widthSpace,
                      Text(
                        '${workout.caloriesBurn?.round() ?? 0} '
                        '${l10n.dashboardKcalUnit}',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onFavorite != null)
              IconButton(
                onPressed: onFavorite,
                icon: Icon(
                  workout.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: workout.isFavorite
                      ? context.colorScheme.error
                      : context.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
