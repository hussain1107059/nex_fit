import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/nutrition_day_summary.dart';
import '../../../domain/entities/nutrition_history.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/nutrition_providers.dart';
import 'widgets/history_bar_chart.dart';
import 'widgets/history_range_selector.dart';
import 'widgets/nutrition_date_format.dart';

/// Nutrition history: day-by-day calories, macros and water over a range.
class NutritionHistoryScreen extends ConsumerWidget {
  const NutritionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<NutritionHistory> async = ref.watch(
      nutritionHistoryProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.nutritionHistory)),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(nutritionHistoryProvider),
        ),
        data: (NutritionHistory history) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              const HistoryRangeSelector(),
              const SizedBox(height: AppSpacing.md),
              _StatsGrid(history: history),
              const SizedBox(height: AppSpacing.md),
              _CalorieTrendCard(history: history),
              const SizedBox(height: AppSpacing.md),
              _DayList(history: history),
            ],
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.history});

  final NutritionHistory history;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: l10n.nutritionAvgCalories,
            value: history.averageCalories.round().toString().toBanglaDigits(),
            icon: Icons.local_fire_department_rounded,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            label: l10n.nutritionLoggedDays,
            value: history.loggedDays.toString().toBanglaDigits(),
            icon: Icons.event_available_rounded,
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            label: l10n.nutritionAvgWater,
            value: history.averageWater.toString().toBanglaDigits(),
            icon: Icons.water_drop_rounded,
            color: theme.colorScheme.tertiary,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
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

class _CalorieTrendCard extends StatelessWidget {
  const _CalorieTrendCard({required this.history});

  final NutritionHistory history;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    if (history.days.isEmpty) {
      return _EmptyCard(
        title: l10n.nutritionNoHistory,
        subtitle: l10n.nutritionNoHistorySubtitle,
      );
    }

    final List<HistoryBarData> bars = history.days.map((NutritionDaySummary day) {
      return HistoryBarData(
        label: day.date.day.toString().toBanglaDigits(),
        value: day.calories,
        color: theme.colorScheme.primary,
      );
    }).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.nutritionCalorieTrend,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          HistoryBarChart(bars: bars),
        ],
      ),
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({required this.history});

  final NutritionHistory history;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    if (history.days.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.nutritionDailyBreakdown,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...history.days.map(
          (NutritionDaySummary day) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatNutritionDate(day.date),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${day.calories.round().toString().toBanglaDigits()} '
                        '${l10n.dashboardKcalUnit}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'P ${day.protein.toStringAsFixed(0).toBanglaDigits()} '
                        'C ${day.carbs.toStringAsFixed(0).toBanglaDigits()} '
                        'F ${day.fat.toStringAsFixed(0).toBanglaDigits()}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: context.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

