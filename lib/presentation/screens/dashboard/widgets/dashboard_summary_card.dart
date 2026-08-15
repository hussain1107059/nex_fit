import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/dashboard_data.dart';

/// Gradient overview card with the headline daily numbers.
class DashboardSummaryCard extends StatelessWidget {
  const DashboardSummaryCard({
    super.key,
    required this.summary,
    this.onSleepTap,
  });

  final DashboardSummary summary;

  /// Opens the sleep history screen when the sleep metric is tapped.
  final VoidCallback? onSleepTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.light;
    final Color onGradient = context.colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: colors.scheme.surface,
        borderRadius: AppRadius.xlRadius,
        border: Border.all(color: colors.scheme.outlineVariant),
        boxShadow: AppShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.dashboardTodayOverview,
                    style: context.textTheme.titleSmall?.copyWith(
                      color: onGradient,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StreakChip(streak: summary.workoutStreak),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _MetricGrid(
              summary: summary,
              onGradient: onGradient,
              onSleepTap: onSleepTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.light;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.scheme.primaryContainer,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 16,
            color: colors.primary,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            '$streak'.toBanglaDigits(),
            style: context.textTheme.labelMedium?.copyWith(
              color: colors.scheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            context.l10n.dashboardDays,
            style: context.textTheme.labelSmall?.copyWith(
              color: colors.scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.summary,
    required this.onGradient,
    this.onSleepTap,
  });

  final DashboardSummary summary;
  final Color onGradient;
  final VoidCallback? onSleepTap;

  @override
  Widget build(BuildContext context) {
    final List<_MetricData> metrics = _metrics(context);

    return GridView.count(
      crossAxisCount: context.isWide ? 3 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: context.isWide ? 1.6 : 1.5,
      children: [
        for (final _MetricData metric in metrics)
          _MetricCell(
            data: metric,
            onGradient: onGradient,
          ),
      ],
    );
  }

  List<_MetricData> _metrics(BuildContext context) {
    final String l10nKg = context.l10n.dashboardKgUnit;
    final String l10nMl = context.l10n.dashboardMlUnit;
    final String weight = summary.weightKg == null
        ? '—'
        : '${summary.weightKg!.toStringAsFixed(1)} $l10nKg'.toBanglaDigits();
    final String bmi = summary.bmi == null
        ? '—'
        : summary.bmi!.toStringAsFixed(1).toBanglaDigits();
    final String sleep = summary.hasSleep
        ? _formatSleep(context, summary.sleepMinutes)
        : '—';

    return <_MetricData>[
      _MetricData(
        icon: Icons.local_fire_department_rounded,
        value: '${summary.caloriesBurned.round()}'.toBanglaDigits(),
        label: context.l10n.dashboardCaloriesBurned,
      ),
      _MetricData(
        icon: Icons.water_drop_rounded,
        value: '${summary.waterMl} $l10nMl'.toBanglaDigits(),
        label: context.l10n.dashboardWater,
      ),
      _MetricData(
        icon: Icons.directions_walk_rounded,
        value: '${summary.steps}'.toBanglaDigits(),
        label: context.l10n.dashboardSteps,
      ),
      _MetricData(
        icon: Icons.monitor_weight_rounded,
        value: weight,
        label: context.l10n.dashboardWeight,
      ),
      _MetricData(
        icon: Icons.calculate_rounded,
        value: bmi,
        label: context.l10n.dashboardBmi,
      ),
      _MetricData(
        icon: Icons.emoji_events_rounded,
        value: '${summary.workoutStreak}'.toBanglaDigits(),
        label: context.l10n.dashboardStreak,
      ),
      _MetricData(
        icon: Icons.bedtime_rounded,
        value: sleep,
        label: context.l10n.dashboardSleep,
        onTap: onSleepTap,
      ),
      _MetricData(
        icon: Icons.stars_rounded,
        value: '${summary.totalXp}'.toBanglaDigits(),
        label: context.l10n.dashboardXp,
      ),
    ];
  }

  /// Formats sleep minutes as `7h 30m` (digits localized).
  String _formatSleep(BuildContext context, int minutes) {
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    final String h = context.l10n.dashboardSleepHour;
    final String m = context.l10n.dashboardSleepMinute;
    return '${'$hours$h'.toBanglaDigits()} '
        '${'$rest$m'.toBanglaDigits()}';
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.data, required this.onGradient});

  final _MetricData data;
  final Color onGradient;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.light;
    final Widget cell = Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.scheme.surfaceContainerHighest,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: colors.scheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(data.icon, size: 16, color: onGradient),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    color: onGradient,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            data.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: context.textTheme.labelSmall?.copyWith(
              color: onGradient.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );

    final VoidCallback? onTap = data.onTap;
    if (onTap == null) return cell;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.mdRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdRadius,
        child: cell,
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;
}
