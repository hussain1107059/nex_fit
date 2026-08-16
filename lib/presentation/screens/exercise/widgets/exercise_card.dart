import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/exercise_category.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../screens/workout/widgets/workout_card.dart';
import 'exercise_cover.dart';

/// Card that links a single exercise to its detail screen.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
    this.onFavorite,
  });

  final Exercise exercise;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ExerciseCategory? category = exercise.category;

    return AppCard(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadius.mdRadius,
              child: SizedBox(
                width: 84,
                height: 84,
                child: ExerciseCover(
                  category: category,
                  height: 84,
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
                    exercise.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (exercise.bodyPart != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      exercise.bodyPart!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
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
                      Flexible(
                        child: Text(
                          '${exercise.totalDurationSeconds.toString().toBanglaDigits()} '
                          '${l10n.workoutSeconds}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      12.widthSpace,
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 14,
                        color: context.colorScheme.tertiary,
                      ),
                      4.widthSpace,
                      Flexible(
                        child: Text(
                          '${exercise.totalEstimatedCalories.round().toString().toBanglaDigits()} '
                          '${l10n.dashboardKcalUnit}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (exercise.difficulty != null) ...[
                    const SizedBox(height: 6),
                    DifficultyChip(difficulty: exercise.difficulty!),
                  ],
                ],
              ),
            ),
            if (onFavorite != null)
              IconButton(
                onPressed: onFavorite,
                icon: Icon(
                  exercise.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: exercise.isFavorite
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
