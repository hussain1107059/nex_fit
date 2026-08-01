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
import '../../../domain/entities/profile_data.dart';
import '../../../domain/entities/user_profile.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/nutrition_providers.dart';
import '../../providers/profile_providers.dart';
import 'widgets/history_bar_chart.dart';
import 'widgets/history_range_selector.dart';
import 'widgets/macro_donut_chart.dart';
import 'widgets/macro_goal_row.dart';

/// Macro Tracker: the protein/carb/fat split averaged over a range, with
/// per-macro goal adherence against the user's targets.
class MacroTrackerScreen extends ConsumerWidget {
  const MacroTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<NutritionHistory> async = ref.watch(
      nutritionHistoryProvider,
    );
    final AsyncValue<ProfileData> profileAsync = ref.watch(
      profileControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.nutritionMacroTracker)),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(nutritionHistoryProvider),
        ),
        data: (NutritionHistory history) {
          final UserProfile? profile = profileAsync.valueOrNull?.profile;
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
              _MacroSplitCard(history: history),              const SizedBox(height: AppSpacing.md),
              if (profile != null)
                _GoalsCard(history: history, profile: profile),
              const SizedBox(height: AppSpacing.md),
              _CalorieTrendCard(history: history, targetCalories: profile?.targetCalories),
            ],
          );
        },
      ),
    );
  }
}

class _MacroSplitCard extends StatelessWidget {
  const _MacroSplitCard({required this.history});

  final NutritionHistory history;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return AppCard(
      child: Column(
        children: [
          Text(
            l10n.nutritionAvgMacros,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          MacroDonutChart(
            slices: <MacroSlice>[
              MacroSlice(
                value: history.averageProtein,
                color: theme.colorScheme.primary,
                label: l10n.nutritionProtein,
              ),
              MacroSlice(
                value: history.averageCarbs,
                color: theme.colorScheme.secondary,
                label: l10n.nutritionCarbs,
              ),
              MacroSlice(
                value: history.averageFat,
                color: theme.colorScheme.tertiary,
                label: l10n.nutritionFat,
              ),
            ],
            centerTitle: history.averageCalories.round().toString().toBanglaDigits(),
            centerSubtitle: l10n.dashboardKcalUnit,
          ),
          const SizedBox(height: AppSpacing.md),
          _LegendRow(
            label: l10n.nutritionProtein,
            value: history.averageProtein,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          _LegendRow(
            label: l10n.nutritionCarbs,
            value: history.averageCarbs,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          _LegendRow(
            label: l10n.nutritionFat,
            value: history.averageFat,
            color: theme.colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '${value.toStringAsFixed(0).toBanglaDigits()}g',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.history, required this.profile});

  final NutritionHistory history;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.nutritionGoalAdherence,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          MacroGoalRow(
            label: l10n.nutritionProtein,
            color: theme.colorScheme.primary,
            current: history.averageProtein,
            target: profile.targetProtein ?? 0,
          ),
          const SizedBox(height: AppSpacing.md),
          MacroGoalRow(
            label: l10n.nutritionCarbs,
            color: theme.colorScheme.secondary,
            current: history.averageCarbs,
            target: profile.targetCarbs ?? 0,
          ),
          const SizedBox(height: AppSpacing.md),
          MacroGoalRow(
            label: l10n.nutritionFat,
            color: theme.colorScheme.tertiary,
            current: history.averageFat,
            target: profile.targetFat ?? 0,
          ),
        ],
      ),
    );
  }
}

class _CalorieTrendCard extends StatelessWidget {
  const _CalorieTrendCard({required this.history, required this.targetCalories});

  final NutritionHistory history;
  final double? targetCalories;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    final List<HistoryBarData> bars = history.days.map((NutritionDaySummary day) {
      return HistoryBarData(
        label: day.date.day.toString().toBanglaDigits(),
        value: day.calories,
        color: theme.colorScheme.primary,
        target: targetCalories,
      );
    }).toList();

    if (bars.isEmpty) {
      return _EmptyHistory(
        title: l10n.nutritionNoHistory,
        subtitle: l10n.nutritionNoHistorySubtitle,
      );
    }

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

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.title, required this.subtitle});

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
              Icons.bar_chart_rounded,
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

