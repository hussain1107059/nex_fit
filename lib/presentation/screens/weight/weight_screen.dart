import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/health_calculator.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/weight_history.dart';
import '../../../domain/entities/weight_log.dart';
import '../../../domain/entities/weight_overview.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/weight_providers.dart';
import '../../router/app_router.dart';
import 'widgets/trend_line_chart.dart';
import 'widgets/weight_entry_tile.dart';
import 'widgets/weight_sheets.dart';

/// Weight tracker & body composition hub (the Progress tab).
class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final AsyncValue<WeightOverview> async = ref.watch(
      weightOverviewControllerProvider,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(weightOverviewControllerProvider.notifier).refresh(),
          child: async.when(
            data: (WeightOverview data) => _WeightContent(
              data: data,
              userId: user.id,
            ),
            error: (Object error, StackTrace stackTrace) => _WeightError(
              onRetry: () => ref
                  .read(weightOverviewControllerProvider.notifier)
                  .refresh(),
            ),
            loading: () => const LoadingWidget(message: null),
          ),
        ),
      ),
    );
  }
}

class _WeightContent extends ConsumerWidget {
  const _WeightContent({required this.data, required this.userId});

  final WeightOverview data;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          automaticallyImplyLeading: true,
          pinned: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          title: Text(
            l10n.weightTracker,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => context.push(AppRoutes.weightHistory),
              icon: const Icon(Icons.history_rounded),
              tooltip: l10n.weightHistory,
            ),
            IconButton(
              onPressed: () => context.push(AppRoutes.weightStatistics),
              icon: const Icon(Icons.bar_chart_rounded),
              tooltip: l10n.weightStatistics,
            ),
            IconButton(
              onPressed: () => context.push(AppRoutes.bodyMeasurement),
              icon: const Icon(Icons.straighten_rounded),
              tooltip: l10n.bodyMeasurementTitle,
            ),
            IconButton(
              onPressed: () => context.push(AppRoutes.progressDashboard),
              icon: const Icon(Icons.insights_rounded),
              tooltip: l10n.progressTitle,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeroCard(data: data),
                    const SizedBox(height: AppSpacing.md),
                    if (!data.hasEntries)
                      _EmptyWeightCard(userId: userId)
                    else ...[
                      _QuickStatsRow(data: data),
                      const SizedBox(height: AppSpacing.md),
                      _CalculatorsCard(data: data),
                      const SizedBox(height: AppSpacing.md),
                      _CompositionCard(data: data),
                      const SizedBox(height: AppSpacing.lg),
                      _TrendSection(data: data),
                      const SizedBox(height: AppSpacing.lg),
                      _EntriesSection(data: data),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.data});

  final WeightOverview data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = AppColors.light;
    final double? weight = data.latestWeight?.weightKg;
    final double? goal = data.goalWeightKg;
    final double? remaining = data.remainingToGoal;
    final double progress = data.targetProgress;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colors.tertiary.withValues(alpha: 0.22),
              colors.primary.withValues(alpha: 0.14),
            ],
          ),
          borderRadius: AppRadius.lgRadius,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.weightCurrent,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    weight == null
                        ? '—'
                        : '${weight.toStringAsFixed(1)} ${l10n.dashboardKgUnit}'
                              .toBanglaDigits(),
                    style: context.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (data.weightDifference != null) ...[
                    _DiffChip(
                      value: data.weightDifference!,
                      inverse: goal != null && goal < weight!,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      l10n.weightSinceStart,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.weightGoalLabel,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    goal == null
                        ? l10n.weightGoalNotSet
                        : '${goal.toStringAsFixed(1)} ${l10n.dashboardKgUnit}'
                              .toBanglaDigits(),
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (remaining != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      remaining <= 0
                          ? l10n.weightGoalReached
                          : '${remaining.abs().toStringAsFixed(1)} ${l10n.dashboardKgUnit} '
                                '${l10n.weightRemainingLabel}'.toBanglaDigits(),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: remaining <= 0
                            ? colors.success
                            : context.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _GoalRing(
              progress: progress,
              valueText:
                  '${(progress * 100).round().toString().toBanglaDigits()}%',
              color: colors.secondary,
              goalSet: goal != null,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalRing extends StatelessWidget {
  const _GoalRing({
    required this.progress,
    required this.valueText,
    required this.color,
    required this.goalSet,
  });

  final double progress;
  final String valueText;
  final Color color;
  final bool goalSet;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (BuildContext context, double value, Widget? child) {
            return SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor: context.colorScheme.surfaceContainerHighest,
                  ),
                  Center(
                    child: Text(
                      valueText,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          goalSet ? context.l10n.weightTargetProgress : context.l10n.weightGoalNotSet,
          textAlign: TextAlign.center,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DiffChip extends StatelessWidget {
  const _DiffChip({required this.value, required this.inverse});

  final double value;

  /// When true, losing weight is the goal (positive diff = on track).
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    final AppColors colors =
        AppColors.light;
    final Color loss = context.colorScheme.primary;
    final Color gain = colors.danger;
    final bool isLoss = inverse ? value <= 0 : value > 0;
    final Color color = isLoss ? loss : gain;
    final IconData icon = isLoss
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(
            '${value.abs().toStringAsFixed(1)} ${context.l10n.dashboardKgUnit}'
                .toBanglaDigits(),
            style: context.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.data});

  final WeightOverview data;

  @override
  Widget build(BuildContext context) {
    final double? bmi = data.bmi;
    final BmiCategory? category = data.bmiCategory;

    return Row(
      children: [
        Expanded(
          child: _StatCell(
            label: context.l10n.weightBmi,
            value: bmi == null
                ? '—'
                : bmi.toStringAsFixed(1).toBanglaDigits(),
            icon: Icons.calculate_rounded,
            color: context.colorScheme.primary,
            subtitle: category == null
                ? null
                : _categoryLabel(context, category),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCell(
            label: context.l10n.weightIdealWeight,
            value: data.idealWeightKg == null
                ? '—'
                : '${data.idealWeightKg!.toStringAsFixed(1)} ${context.l10n.dashboardKgUnit}'
                      .toBanglaDigits(),
            icon: Icons.flag_rounded,
            color: context.colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCell(
            label: context.l10n.weightWeeklyChange,
            value: _weeklyChange(data) == null
                ? '—'
                : '${_weeklyChange(data)!.toStringAsFixed(1)} ${context.l10n.dashboardKgUnit}'
                      .toBanglaDigits(),
            icon: Icons.trending_up_rounded,
            color: context.colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  double? _weeklyChange(WeightOverview data) {
    final DateTime now = DateTime.now();
    final DateTime cutoff = now.subtract(const Duration(days: 7));
    final List<WeightLog> recent = data.logs
        .where((WeightLog log) => log.loggedAt.isAfter(cutoff))
        .toList();
    if (recent.length < 2) return null;
    return recent.last.weightKg - recent.first.weightKg;
  }

  String _categoryLabel(BuildContext context, BmiCategory category) {
    final AppLocalizations l10n = context.l10n;
    return switch (category) {
      BmiCategory.underweight => l10n.bmiUnderweight,
      BmiCategory.normal => l10n.bmiNormal,
      BmiCategory.overweight => l10n.bmiOverweight,
      BmiCategory.obese => l10n.bmiObese,
    };
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle ?? label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculatorsCard extends StatelessWidget {
  const _CalculatorsCard({required this.data});

  final WeightOverview data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final double? bmr = data.bmr;
    final double? calories = data.dailyCalories;
    final ({double minKg, double maxKg})? range = data.healthyRange;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.weightCalculators,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _CalcRow(
            icon: Icons.local_fire_department_rounded,
            label: l10n.weightBmr,
            value: bmr == null
                ? l10n.weightNeedProfile
                : '${bmr.round().toString().toBanglaDigits()} ${l10n.dashboardKcalUnit}',
            color: context.colorScheme.secondary,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CalcRow(
            icon: Icons.bolt_rounded,
            label: l10n.weightDailyCalories,
            value: calories == null
                ? l10n.weightNeedProfile
                : '${calories.round().toString().toBanglaDigits()} ${l10n.dashboardKcalUnit}',
            color: context.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CalcRow(
            icon: Icons.monitor_weight_rounded,
            label: l10n.weightHealthyRange,
            value: range == null
                ? l10n.weightNeedProfile
                : '${range.minKg.toStringAsFixed(1)} – '
                      '${range.maxKg.toStringAsFixed(1)} ${l10n.dashboardKgUnit}'
                      .toBanglaDigits(),
            color: context.colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}

class _CalcRow extends StatelessWidget {
  const _CalcRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          value,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CompositionCard extends StatelessWidget {
  const _CompositionCard({required this.data});

  final WeightOverview data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors =
        AppColors.light;
    final double? bodyFat = data.bodyFatPercent;
    final double? lbm = data.leanBodyMassKg;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.weightComposition,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _CompositionCell(
                  label: l10n.weightBodyFat,
                  value: bodyFat == null
                      ? '—'
                      : '${bodyFat.toStringAsFixed(1)}%'.toBanglaDigits(),
                  icon: Icons.water_drop_rounded,
                  color: colors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _CompositionCell(
                  label: l10n.weightLeanMass,
                  value: lbm == null
                      ? '—'
                      : '${lbm.toStringAsFixed(1)} ${l10n.dashboardKgUnit}'
                            .toBanglaDigits(),
                  icon: Icons.fitness_center_rounded,
                  color: context.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.weightBodyFatHint,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompositionCell extends StatelessWidget {
  const _CompositionCell({
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendSection extends ConsumerWidget {
  const _TrendSection({required this.data});

  final WeightOverview data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final WeightHistoryPeriod period = ref.watch(weightHistoryPeriodProvider);
    final AsyncValue<WeightHistory> async = ref.watch(weightHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              l10n.weightTrend,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.push(AppRoutes.weightHistory),
              child: Text(l10n.commonViewAll),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<WeightHistoryPeriod>(
          showSelectedIcon: false,
          segments: <ButtonSegment<WeightHistoryPeriod>>[
            ButtonSegment<WeightHistoryPeriod>(
              value: WeightHistoryPeriod.daily,
              label: Text(l10n.weightHistoryDaily),
            ),
            ButtonSegment<WeightHistoryPeriod>(
              value: WeightHistoryPeriod.weekly,
              label: Text(l10n.weightHistoryWeekly),
            ),
            ButtonSegment<WeightHistoryPeriod>(
              value: WeightHistoryPeriod.monthly,
              label: Text(l10n.weightHistoryMonthly),
            ),
            ButtonSegment<WeightHistoryPeriod>(
              value: WeightHistoryPeriod.yearly,
              label: Text(l10n.weightHistoryYearly),
            ),
          ],
          selected: <WeightHistoryPeriod>{period},
          onSelectionChanged: (Set<WeightHistoryPeriod> selection) {
            ref.read(weightHistoryPeriodProvider.notifier).state =
                selection.first;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        async.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace stackTrace) => const SizedBox(
            height: 160,
            child: Center(child: Text('—')),
          ),
          data: (WeightHistory history) => _TrendChart(
            history: history,
            color: context.colorScheme.tertiary,
          ),
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.history, required this.color});

  final WeightHistory history;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<WeightHistoryBucket> buckets = history.buckets;

    if (buckets.every((WeightHistoryBucket b) => b.entries == 0)) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            children: [
              Icon(
                Icons.show_chart_rounded,
                size: 44,
                color: context.colorScheme.outlineVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.weightNoHistory,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.weightNoHistorySubtitle,
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

    final List<TrendPoint> points = <TrendPoint>[];
    for (int i = 0; i < buckets.length; i++) {
      final WeightHistoryBucket bucket = buckets[i];
      if (bucket.entries == 0) continue;
      points.add(
        TrendPoint(
          x: i.toDouble(),
          y: bucket.latestWeightKg,
          label: _labelFor(history.period, bucket, i),
          tooltip: '${bucket.latestWeightKg.toStringAsFixed(1)} '
              '${l10n.dashboardKgUnit}',
        ),
      );
    }

    return TrendChartCard(
      title: _titleFor(history),
      child: TrendLineChart(
        points: points,
        color: color,
        height: 200,
      ),
    );
  }

  String _labelFor(
    WeightHistoryPeriod period,
    WeightHistoryBucket bucket,
    int index,
  ) {
    return switch (period) {
      WeightHistoryPeriod.daily =>
        bucket.start.day.toString().toBanglaDigits(),
      WeightHistoryPeriod.weekly =>
        'W${(index + 1).toString().toBanglaDigits()}',
      WeightHistoryPeriod.monthly =>
        bucket.start.month.toString().toBanglaDigits(),
      WeightHistoryPeriod.yearly =>
        bucket.start.year.toString().toBanglaDigits(),
    };
  }

  String _titleFor(WeightHistory history) {
    final DateTime start = history.start;
    return switch (history.period) {
      WeightHistoryPeriod.daily =>
        '${start.day.toString().toBanglaDigits()} – '
            '${history.end.day.toString().toBanglaDigits()} '
            '${_monthName(start.month)}',
      WeightHistoryPeriod.weekly =>
        '${_monthName(start.month)} ${start.year.toString().toBanglaDigits()}',
      WeightHistoryPeriod.monthly => start.year.toString().toBanglaDigits(),
      WeightHistoryPeriod.yearly =>
        '${start.year.toString().toBanglaDigits()} – '
            '${history.end.year.toString().toBanglaDigits()}',
    };
  }

  String _monthName(int month) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}

class _EntriesSection extends ConsumerWidget {
  const _EntriesSection({required this.data});

  final WeightOverview data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<WeightLog> logs = data.logs.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${l10n.weightEntries} (${data.entriesCount.toString().toBanglaDigits()})',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => showWeightEntrySheet(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.weightLogTitle),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final WeightLog log in logs.take(20)) WeightEntryTile(log: log),
      ],
    );
  }
}

class _EmptyWeightCard extends ConsumerWidget {
  const _EmptyWeightCard({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            Icon(
              Icons.monitor_weight_rounded,
              size: 48,
              color: context.colorScheme.outlineVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.weightNoEntries,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.weightNoEntriesSubtitle,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => showWeightEntrySheet(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.weightLogTitle),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightError extends StatelessWidget {
  const _WeightError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: ErrorWidget(
                title: context.l10n.errorDatabase,
                subtitle: context.l10n.errorDatabaseSubtitle,
                onRetry: onRetry,
              ),
            ),
          ],
        );
      },
    );
  }
}
