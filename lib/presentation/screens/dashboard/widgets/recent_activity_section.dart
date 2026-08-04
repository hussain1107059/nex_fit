import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/dashboard_data.dart';
import 'empty_workout_card.dart';
import 'section_header.dart';

/// Latest activity feed plus the no-workout illustration empty state.
class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: context.l10n.dashboardRecentActivity),
        if (!data.summary.hasWorkouts) ...[
          const EmptyWorkoutCard(),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (data.recentActivity.isEmpty)
          _EmptyActivity()
        else
          Card(
            child: Column(
              children: [
                for (int i = 0; i < data.recentActivity.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 64,
                      endIndent: AppSpacing.md,
                      color: context.colorScheme.outlineVariant,
                    ),
                  _ActivityTile(item: data.recentActivity[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 36,
              color: context.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.dashboardNoActivity,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.dashboardNoActivitySubtitle,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final RecentActivityItem item;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.light;
    final (IconData icon, Color color) = switch (item.kind) {
      DashboardActivityKind.workout => (
        Icons.fitness_center_rounded,
        colors.primary,
      ),
      DashboardActivityKind.water => (Icons.water_drop_rounded, colors.info),
      DashboardActivityKind.meal => (Icons.restaurant_rounded, colors.warning),
      DashboardActivityKind.weight => (
        Icons.monitor_weight_rounded,
        colors.tertiary,
      ),
      DashboardActivityKind.sleep => (Icons.bedtime_rounded, colors.success),
    };

    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        _title(context),
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        _time(context),
        style: context.textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        _value(context),
        style: context.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _title(BuildContext context) {
    return switch (item.kind) {
      DashboardActivityKind.workout => context.l10n.dashboardActivityWorkout,
      DashboardActivityKind.water => context.l10n.dashboardActivityWater,
      DashboardActivityKind.meal => context.l10n.dashboardActivityMeal,
      DashboardActivityKind.weight => context.l10n.dashboardActivityWeight,
      DashboardActivityKind.sleep => context.l10n.dashboardActivitySleep,
    };
  }

  String _time(BuildContext context) {
    final DateTime local = item.occurredAt.toLocal();
    final DateTime now = DateTime.now();
    final bool isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final String formatted = isToday
        ? DateFormat('h:mm a').format(local)
        : DateFormat('d MMM').format(local);
    return formatted.toBanglaDigits();
  }

  String _value(BuildContext context) {
    final double? value = item.value;
    if (value == null) return '';
    return switch (item.kind) {
      DashboardActivityKind.workout =>
        '${value.round()} ${context.l10n.dashboardMinutesShort}',
      DashboardActivityKind.water =>
        '${value.round()} ${context.l10n.dashboardMlUnit}',
      DashboardActivityKind.meal =>
        '${value.round()} ${context.l10n.dashboardKcalUnit}',
      DashboardActivityKind.weight =>
        '${value.toStringAsFixed(1)} ${context.l10n.dashboardKgUnit}',
      DashboardActivityKind.sleep => _formatSleepMinutes(context, value.round()),
    }.toBanglaDigits();
  }

  String _formatSleepMinutes(BuildContext context, int minutes) {
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    return '$hours${context.l10n.dashboardHoursShort} $rest m';
  }
}
