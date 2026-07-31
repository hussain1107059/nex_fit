import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../domain/entities/workout_library.dart';
import '../../../../l10n/app_localizations.dart';
import 'workout_cover.dart';

/// Banner shown when an in-progress session can be resumed.
class ContinueWorkoutCard extends StatelessWidget {
  const ContinueWorkoutCard({
    super.key,
    required this.continueWorkout,
    required this.onResume,
  });

  final ContinueWorkout continueWorkout;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double progress = continueWorkout.progress.clamp(0.0, 1.0);

    return AppCard(
      padding: EdgeInsets.zero,
      gradient: LinearGradient(
        colors: context.isDarkMode
            ? <Color>[
                context.colorScheme.primaryContainer,
                context.colorScheme.surface,
              ]
            : <Color>[const Color(0xFFE7F5EC), context.colorScheme.surface],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadius.mdRadius,
              child: SizedBox(
                width: 72,
                height: 72,
                child: WorkoutCover(
                  colorValue: context.colorScheme.primary.toARGB32(),
                  icon: Icons.play_circle_fill_rounded,
                ),
              ),
            ),
            AppSpacing.md.widthSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.workoutContinueTitle,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    continueWorkout.workout.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: AppRadius.pillRadius,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor:
                          context.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${continueWorkout.completedExercises.toString().toBanglaDigits()} / '
                    '${continueWorkout.totalExercises.toString().toBanglaDigits()} '
                    '${l10n.workoutExercises.toLowerCase()}',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.sm.widthSpace,
            AppButton(
              onPressed: onResume,
              label: l10n.workoutResume,
              size: AppButtonSize.small,
              icon: Icons.play_arrow_rounded,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}
