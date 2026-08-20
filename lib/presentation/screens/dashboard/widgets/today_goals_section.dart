import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/dashboard_data.dart';
import 'goal_ring.dart';
import 'section_header.dart';

/// Four animated circular progress goals for today.
class TodayGoalsSection extends StatelessWidget {
  const TodayGoalsSection({super.key, required this.goals});

  final TodayGoals goals;

  double _progress(double value, double target) {
    if (target <= 0) return 0;
    return (value / target).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.light;
    final String l10nMin = context.l10n.dashboardMinutesShort;
    final String l10nKcal = context.l10n.dashboardKcalUnit;
    final String l10nMl = context.l10n.dashboardMlUnit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: context.l10n.dashboardTodaysGoal),
        GridView.count(
          crossAxisCount: context.isWide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: context.isWide ? 1.15 : 0.85,
          children: [
            GoalRing(
              progress: _progress(
                goals.workoutMinutes.toDouble(),
                goals.workoutMinutesTarget.toDouble(),
              ),
              valueText: '${goals.workoutMinutes}'.toBanglaDigits(),
              label: context.l10n.dashboardWorkoutMinutes,
              icon: Icons.fitness_center_rounded,
              color: colors.primary,
              targetText: '${goals.workoutMinutesTarget} $l10nMin'.toBanglaDigits(),
            ),
            GoalRing(
              progress: _progress(goals.caloriesConsumed, goals.calorieTarget ?? 0),
              valueText: '${goals.caloriesConsumed.round()}'.toBanglaDigits(),
              label: context.l10n.dashboardCalories,
              icon: Icons.restaurant_rounded,
              color: colors.warning,
              goalSet: goals.calorieTarget != null && goals.calorieTarget! > 0,
              targetText: goals.calorieTarget == null
                  ? null
                  : '${goals.calorieTarget!.round()} $l10nKcal'.toBanglaDigits(),
            ),
            GoalRing(
              progress: _progress(
                goals.waterMl.toDouble(),
                (goals.waterTargetMl ?? 0).toDouble(),
              ),
              valueText: '${goals.waterMl}'.toBanglaDigits(),
              label: context.l10n.dashboardWater,
              icon: Icons.water_drop_rounded,
              color: colors.info,
              goalSet: goals.waterTargetMl != null && goals.waterTargetMl! > 0,
              targetText: goals.waterTargetMl == null
                  ? null
                  : '${goals.waterTargetMl} $l10nMl'.toBanglaDigits(),
            ),
            GoalRing(
              progress: _progress(
                goals.steps.toDouble(),
                (goals.stepTarget ?? 0).toDouble(),
              ),
              valueText: '${goals.steps}'.toBanglaDigits(),
              label: context.l10n.dashboardSteps,
              icon: Icons.directions_walk_rounded,
              color: colors.success,
              goalSet: goals.stepTarget != null && goals.stepTarget! > 0,
              targetText: goals.stepTarget == null
                  ? null
                  : '${goals.stepTarget}'.toBanglaDigits(),
            ),
          ],
        ),
      ],
    );
  }
}
