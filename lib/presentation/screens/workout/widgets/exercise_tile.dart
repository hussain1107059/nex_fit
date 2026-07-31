import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../domain/entities/workout_exercise_detail.dart';
import '../../../../l10n/app_localizations.dart';

/// A single ordered exercise inside a workout routine.
class ExerciseTile extends StatelessWidget {
  const ExerciseTile({
    super.key,
    required this.detail,
    required this.index,
    this.onTap,
  });

  final WorkoutExerciseDetail detail;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int reps = detail.reps;
    final int duration = detail.durationSeconds;

    final String measure;
    if (reps > 0) {
      measure = '${reps.toString().toBanglaDigits()} ${l10n.workoutReps}';
    } else if (duration > 0) {
      measure =
          '${duration.toString().toBanglaDigits()} ${l10n.workoutSeconds}';
    } else {
      measure = l10n.workoutTimed;
    }

    return AppCard(
      onPressed: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colorScheme.primaryContainer,
            ),
            child: Text(
              (index + 1).toString().toBanglaDigits(),
              style: context.textTheme.titleSmall?.copyWith(
                color: context.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          AppSpacing.md.widthSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail.exercise.bodyPart != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail.exercise.bodyPart!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppSpacing.sm.widthSpace,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${detail.sets.toString().toBanglaDigits()} ×',
                style: context.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                measure,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
