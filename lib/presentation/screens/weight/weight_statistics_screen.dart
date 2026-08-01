import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/weight_statistics.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/weight_providers.dart';

/// Lifetime weight statistics card grid.
class WeightStatisticsScreen extends ConsumerWidget {
  const WeightStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WeightStatistics> async = ref.watch(
      weightStatisticsProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.weightStatistics)),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(weightStatisticsProvider),
        ),
        data: (WeightStatistics stats) => _StatsContent(stats: stats),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({required this.stats});

  final WeightStatistics stats;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppColors colors =
        context.isDarkMode ? AppColors.dark : AppColors.light;
    final String kg = l10n.dashboardKgUnit;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: l10n.weightStatStart,
                value: _format(stats.startWeightKg),
                unit: kg,
                icon: Icons.play_arrow_rounded,
                color: theme.colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                label: l10n.weightStatCurrent,
                value: _format(stats.currentWeightKg),
                unit: kg,
                icon: Icons.flag_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: l10n.weightStatMin,
                value: _format(stats.minWeightKg),
                unit: kg,
                icon: Icons.arrow_downward_rounded,
                color: colors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                label: l10n.weightStatMax,
                value: _format(stats.maxWeightKg),
                unit: kg,
                icon: Icons.arrow_upward_rounded,
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: l10n.weightStatAverage,
                value: _format(stats.averageWeightKg),
                unit: kg,
                icon: Icons.calculate_rounded,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                label: l10n.weightStatTotalChange,
                value: _format(stats.totalChangeKg),
                unit: kg,
                icon: stats.totalChangeKg == null ||
                        stats.totalChangeKg! <= 0
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: stats.totalChangeKg == null || stats.totalChangeKg! <= 0
                    ? colors.success
                    : theme.colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                label: l10n.weightStatDaysTracked,
                value: stats.daysTracked.toString().toBanglaDigits(),
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MiniStatCard(
                label: l10n.weightStatTotalEntries,
                value: stats.totalEntries.toString().toBanglaDigits(),
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: l10n.weightStatCurrentStreak,
                value: stats.currentStreak.toString().toBanglaDigits(),
                unit: _streakUnit(l10n, stats.currentStreak),
                icon: Icons.local_fire_department_rounded,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatCard(
                label: l10n.weightStatLongestStreak,
                value: stats.longestStreak.toString().toBanglaDigits(),
                unit: _streakUnit(l10n, stats.longestStreak),
                icon: Icons.emoji_events_rounded,
                color: theme.colorScheme.tertiary,
              ),
            ),
          ],
        ),
        if (stats.firstDate != null && stats.lastDate != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _DateRangeCard(stats: stats),
        ],
      ],
    );
  }

  String _format(double? value) {
    return value == null
        ? '—'
        : value.toStringAsFixed(1).toBanglaDigits();
  }

  String _streakUnit(AppLocalizations l10n, int days) {
    return l10n.weightStreakDays(days.toString().toBanglaDigits());
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 17, color: color),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              unit,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRangeCard extends StatelessWidget {
  const _DateRangeCard({required this.stats});

  final WeightStatistics stats;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.date_range_rounded,
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.weightStatTrackedPeriod,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(stats.firstDate!)} – '
                  '${_formatDate(stats.lastDate!)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day.toString().toBanglaDigits()} '
        '${months[date.month - 1]} '
        '${date.year.toString().toBanglaDigits()}';
  }
}
