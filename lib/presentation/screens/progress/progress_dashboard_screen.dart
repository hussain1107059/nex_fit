import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/progress/analytics_report.dart';
import '../../../domain/entities/progress/fitness_score.dart';
import '../../../domain/entities/progress/goal_progress.dart';
import '../../../domain/entities/progress/personal_record.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/progress_providers.dart';
import '../../router/app_router.dart';
import '../weight/widgets/trend_line_chart.dart';
import 'widgets/analytics_bar_chart.dart';
import 'widgets/progress_export.dart';
import 'widgets/progress_widgets.dart';

/// Progress & Analytics hub: period filter, fitness score, summary stats,
/// key charts and shortcuts to reports, records and goals.
class ProgressDashboardScreen extends ConsumerWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final AsyncValue<AnalyticsReport> reportAsync = ref.watch(
      progressReportControllerProvider,
    );
    final AsyncValue<List<GoalProgress>> goalsAsync = ref.watch(
      goalProgressProvider,
    );
    final AsyncValue<List<PersonalRecord>> recordsAsync = ref.watch(
      personalRecordsProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.progressTitle,
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push(AppRoutes.progressScore),
            icon: const Icon(Icons.speed_rounded),
            tooltip: context.l10n.progressScoreTitle,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(progressReportControllerProvider.notifier).refresh(),
        child: reportAsync.when(
          loading: () => const LoadingWidget(message: null),
          error: (Object error, StackTrace stackTrace) => ErrorWidget(
            title: context.l10n.errorDatabase,
            subtitle: context.l10n.errorDatabaseSubtitle,
            onRetry: () =>
                ref.read(progressReportControllerProvider.notifier).refresh(),
          ),
          data: (AnalyticsReport report) => _DashboardContent(
            report: report,
            goalsAsync: goalsAsync,
            recordsAsync: recordsAsync,
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.report,
    required this.goalsAsync,
    required this.recordsAsync,
  });

  final AnalyticsReport report;
  final AsyncValue<List<GoalProgress>> goalsAsync;
  final AsyncValue<List<PersonalRecord>> recordsAsync;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        const PeriodFilter(),
        const SizedBox(height: AppSpacing.md),
        if (!report.hasAnyData)
          const _EmptyReportCard()
        else ...<Widget>[
          const _ScoreCard(),
          const SizedBox(height: AppSpacing.md),
          _SummaryGrid(report: report),
          const SizedBox(height: AppSpacing.md),
          _ChartCard(
            title: l10n.progressChartCalories,
            child: _CaloriesChart(report: report),
          ),
          const SizedBox(height: AppSpacing.md),
          _ChartCard(
            title: l10n.progressChartWater,
            child: _WaterChart(report: report),
          ),
          const SizedBox(height: AppSpacing.md),
          _ChartCard(
            title: l10n.progressChartSteps,
            child: _StepsChart(report: report),
          ),
          const SizedBox(height: AppSpacing.md),
          _ChartCard(
            title: l10n.progressChartWeight,
            child: _WeightChart(report: report),
          ),
          const SizedBox(height: AppSpacing.md),
          _GoalsSection(goalsAsync: goalsAsync),
          const SizedBox(height: AppSpacing.md),
          _RecordsSection(recordsAsync: recordsAsync),
          const SizedBox(height: AppSpacing.md),
          _ReportActions(report: report),
        ],
      ],
    );
  }
}

class _EmptyReportCard extends StatelessWidget {
  const _EmptyReportCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.insights_rounded,
              size: 48,
              color: context.colorScheme.outlineVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.progressEmptyTitle,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.progressEmptySubtitle,
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

class _ScoreCard extends ConsumerWidget {
  const _ScoreCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<FitnessScore> scoreAsync = ref.watch(fitnessScoreProvider);

    return AppCard(
      onPressed: () => context.push(AppRoutes.progressScore),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: context.colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.speed_rounded,
              color: context.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.progressScoreTitle,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scoreAsync.maybeWhen(
                    data: (FitnessScore data) => _scoreLabel(context, data),
                    orElse: () => '—',
                  ),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            scoreAsync.maybeWhen(
              data: (FitnessScore data) =>
                  '${data.score.toString().toBanglaDigits()}/100',
              orElse: () => '—',
            ),
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: context.colorScheme.primary,
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    );
  }

  String _scoreLabel(BuildContext context, FitnessScore data) {
    final AppLocalizations l10n = context.l10n;
    if (data.score >= 80) return l10n.progressScoreExcellent;
    if (data.score >= 60) return l10n.progressScoreGood;
    if (data.score >= 40) return l10n.progressScoreFair;
    if (data.score >= 20) return l10n.progressScoreNeedsWork;
    return l10n.progressScoreGettingStarted;
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors =
        AppColors.light;
    final String kcal = l10n.dashboardKcalUnit;
    final String ml = l10n.progressUnitMl;
    final String kg = l10n.dashboardKgUnit;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                label: l10n.progressSummaryWorkouts,
                value: report.summary.workoutCount
                    .toString()
                    .toBanglaDigits(),
                color: context.colorScheme.primary,
                icon: Icons.fitness_center_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                label: l10n.progressSummaryCaloriesBurned,
                value:
                    '${report.summary.caloriesBurned.round().toString().toBanglaDigits()} $kcal',
                color: colors.secondary,
                icon: Icons.local_fire_department_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                label: l10n.progressSummaryActiveDays,
                value: report.summary.activeDays.toString().toBanglaDigits(),
                color: colors.info,
                icon: Icons.event_available_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                label: l10n.progressSummaryAvgWater,
                value:
                    '${report.summary.avgWaterMlPerDay.toString().toBanglaDigits()} $ml',
                color: colors.info,
                icon: Icons.water_drop_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                label: l10n.progressSummaryAvgSleep,
                value:
                    '${report.summary.avgSleepHoursPerDay.toStringAsFixed(1).toBanglaDigits()} ${l10n.progressUnitHours}',
                color: colors.tertiary,
                icon: Icons.bedtime_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatTile(
                label: l10n.progressSummaryWeightChange,
                value: report.summary.weightChangeKg == null
                    ? '—'
                    : '${report.summary.weightChangeKg!.toStringAsFixed(1).toBanglaDigits()} $kg',
                color: report.summary.weightChangeKg == null ||
                        report.summary.weightChangeKg! <= 0
                    ? colors.success
                    : colors.danger,
                icon: Icons.monitor_weight_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _CaloriesChart extends StatelessWidget {
  const _CaloriesChart({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final AppColors colors =
        AppColors.light;
    final List<TrendPoint> points = <TrendPoint>[];
    for (int i = 0; i < report.series.length; i++) {
      final point = report.series[i];
      points.add(
        TrendPoint(
          x: i.toDouble(),
          y: point.caloriesBurned,
          label: point.label,
          tooltip:
              '${point.caloriesBurned.round().toString().toBanglaDigits()} '
              '${context.l10n.dashboardKcalUnit}',
        ),
      );
    }
    return TrendLineChart(points: points, color: colors.secondary);
  }
}

class _WaterChart extends StatelessWidget {
  const _WaterChart({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final AppColors colors =
        AppColors.light;
    final String ml = context.l10n.progressUnitMl;
    final List<TrendPoint> points = <TrendPoint>[];
    for (int i = 0; i < report.series.length; i++) {
      final point = report.series[i];
      points.add(
        TrendPoint(
          x: i.toDouble(),
          y: point.waterMl.toDouble(),
          label: point.label,
          tooltip: '${point.waterMl.toString().toBanglaDigits()} $ml',
        ),
      );
    }
    return AnalyticsBarChart(points: points, color: colors.info);
  }
}

class _StepsChart extends StatelessWidget {
  const _StepsChart({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final AppColors colors =
        AppColors.light;
    final List<TrendPoint> points = <TrendPoint>[];
    for (int i = 0; i < report.series.length; i++) {
      final point = report.series[i];
      points.add(
        TrendPoint(
          x: i.toDouble(),
          y: point.steps.toDouble(),
          label: point.label,
          tooltip:
              '${point.steps.toString().toBanglaDigits()} '
              '${context.l10n.progressUnitSteps}',
        ),
      );
    }
    return AnalyticsBarChart(points: points, color: colors.success);
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final AppColors colors =
        AppColors.light;
    final String kg = context.l10n.dashboardKgUnit;
    final List<TrendPoint> points = <TrendPoint>[];
    for (int i = 0; i < report.series.length; i++) {
      final point = report.series[i];
      final double? weight = point.weightKg;
      if (weight == null) continue;
      points.add(
        TrendPoint(
          x: i.toDouble(),
          y: weight,
          label: point.label,
          tooltip: '${weight.toStringAsFixed(1).toBanglaDigits()} $kg',
        ),
      );
    }
    return TrendLineChart(points: points, color: colors.tertiary);
  }
}

class _GoalsSection extends StatelessWidget {
  const _GoalsSection({required this.goalsAsync});

  final AsyncValue<List<GoalProgress>> goalsAsync;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<GoalProgress>? goals = goalsAsync.value;
    final List<GoalProgress> visible = goals == null
        ? const <GoalProgress>[]
        : goals.take(3).toList();

    return ProgressSectionCard(
      title: l10n.progressGoals,
      trailing: TextButton(
        onPressed: () => context.push(AppRoutes.progressGoals),
        child: Text(l10n.commonViewAll),
      ),
      child: goalsAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (Object error, StackTrace stackTrace) => Text('—'),
        data: (_) => visible.isEmpty
            ? Text(
                l10n.progressGoalNotSet,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              )
            : Column(
                children: <Widget>[
                  for (int i = 0; i < visible.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    GoalProgressTile(goal: visible[i]),
                  ],
                ],
              ),
      ),
    );
  }
}

class _RecordsSection extends StatelessWidget {
  const _RecordsSection({required this.recordsAsync});

  final AsyncValue<List<PersonalRecord>> recordsAsync;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<PersonalRecord>? records = recordsAsync.value;
    final List<PersonalRecord> visible = records == null
        ? const <PersonalRecord>[]
        : records.take(3).toList();

    return ProgressSectionCard(
      title: l10n.progressRecords,
      trailing: TextButton(
        onPressed: () => context.push(AppRoutes.progressRecords),
        child: Text(l10n.commonViewAll),
      ),
      child: recordsAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (Object error, StackTrace stackTrace) => Text('—'),
        data: (_) => visible.isEmpty
            ? Text(
                l10n.progressNoRecords,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              )
            : Column(
                children: <Widget>[
                  for (int i = 0; i < visible.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    RecordTile(record: visible[i]),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ReportActions extends StatelessWidget {
  const _ReportActions({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.progressReport),
          icon: const Icon(Icons.assignment_rounded),
          label: Text(l10n.progressFullReport),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => showProgressExportSheet(context, report),
          icon: const Icon(Icons.ios_share_rounded),
          label: Text(l10n.progressExport),
        ),
      ],
    );
  }
}
