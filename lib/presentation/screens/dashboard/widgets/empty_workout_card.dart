import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';

/// Illustrated empty state shown when the user has no workouts yet.
class EmptyWorkoutCard extends StatelessWidget {
  const EmptyWorkoutCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colorScheme.primaryContainer.withValues(alpha: 0.6),
            context.colorScheme.secondaryContainer.withValues(alpha: 0.4),
          ],
        ),
        border: Border.all(color: context.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.colorScheme.surface.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                Icons.fitness_center_rounded,
                size: 34,
                color: context.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.dashboardNoWorkoutYet,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  context.l10n.dashboardNoWorkoutYetSubtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  onPressed: () =>
                      AppSnackbar.info(context, context.l10n.dashboardComingSoon),
                  label: context.l10n.dashboardFirstWorkout,
                  icon: Icons.play_arrow_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  fullWidth: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
