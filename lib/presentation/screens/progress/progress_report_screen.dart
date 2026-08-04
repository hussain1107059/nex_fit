import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/progress/analytics_report.dart';
import '../../../domain/entities/progress/analytics_summary.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/progress_providers.dart';
import '../weight/widgets/trend_line_chart.dart';
import 'widgets/analytics_bar_chart.dart';
import 'widgets/progress_export.dart';
import 'widgets/progress_widgets.dart';

/// Full progress report: summary totals, averages, every analytics chart and
/// a calorie-balance breakdown, with PDF / CSV / Excel export.
class ProgressReportScreen extends ConsumerWidget {
  const ProgressReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AnalyticsReport> async = ref.watch(
      progressReportControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.progressReportTitle)),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(progressReportControllerProvider.notifier).refresh(),
        child: async.when(
          loading: () => const LoadingWidget(message: null),
          error: (Object error, StackTrace stackTrace) => ErrorWidget(
            title: context.l10n.errorDatabase,
            subtitle: context.l10n.errorDatabaseSubtitle,
            onRetry: () =>
                ref.read(progressReportControllerProvider.notifier).refresh(),
          ),
          data: (AnalyticsReport report) => _ReportContent(report: report),
        ),
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.report});

  final AnalyticsReport report;

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
          AppCard(
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
                    l10n.progressEmptyTitle,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.progressEmptySubtitle,
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...<Widget>[
          _TotalsCard(summary: report.summary),
          const SizedBox(height: AppSpacing.md),
          _AveragesCard(summary: report.summary),
          const SizedBox(height: AppSpacing.md),
          _ChartCard(
            title: l10n.progressChartCalories,
            child: _CaloriesChart(report: report),
          ),
          const SizedBox(height: AppSpacing.md),
          _ChartCard(
            title: l10n.progressChartWorkoutMinutes,
            child: _WorkoutMinutesChart(report: report),
          ),
          const SizedBox(height: AppSpacing.md),
          _ChartCard(
            title: l10n.progressChartWorkoutCount,
            child: _WorkoutCountChart(report: report),
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
            title: l10n.progressChartSleep,
            child: _SleepChart(report: report),
          ),
          const SizedBox(height: AppSpacing.md),
          _ChartCard(
            title: l10n.progressChartWeight,
            child: _WeightChart(report: report),
          ),
          const SizedBox(height: AppSpacing.md),
          _ChartCard(
            title: l10n.progressChartBmi,
            child: _BmiChart(report: report),
          ),
          const SizedBox(height: AppSpacing.md),
          _BalanceCard(report: report),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => showProgressExportSheet(context, report),
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(l10n.progressExport),
          ),
        ],
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String kcal = l10n.dashboardKcalUnit;
    final String kg = l10n.dashboardKgUnit;

    return ProgressSectionCard(
      title: l10n.progressTotal,
      child: Column(
        children: <Widget>[
          _TotalsRow(
            leftLabel: l10n.progressSummaryWorkouts,
            leftValue: summary.workoutCount.toString().toBanglaDigits(),
            rightLabel: l10n.progressChartWorkoutMinutes,
            rightValue: summary.workoutMinutes
                .round()
                .toString()
                .toBanglaDigits(),
          ),
          const Divider(height: 20),
          _TotalsRow(
            leftLabel: l10n.progressSummaryCaloriesBurned,
            leftValue:
                '${summary.caloriesBurned.round().toString().toBanglaDigits()} $kcal',
            rightLabel: l10n.progressSummaryCaloriesConsumed,
            rightValue:
                '${summary.caloriesConsumed.round().toString().toBanglaDigits()} $kcal',
          ),
          const Divider(height: 20),
          _TotalsRow(
            leftLabel: l10n.progressChartWater,
            leftValue:
                '${summary.waterMl.toString().toBanglaDigits()} ${l10n.progressUnitMl}',
            rightLabel: l10n.progressChartSteps,
            rightValue:
                '${summary.steps.toString().toBanglaDigits()} ${l10n.progressUnitSteps}',
          ),
          const Divider(height: 20),
          _TotalsRow(
            leftLabel: l10n.progressChartSleep,
            leftValue:
                '${(summary.sleepMinutes / 60).toStringAsFixed(1).toBanglaDigits()} ${l10n.progressUnitHours}',
            rightLabel: l10n.progressSummaryWeightChange,
            rightValue: summary.weightChangeKg == null
                ? '—'
                : '${summary.weightChangeKg!.toStringAsFixed(1).toBanglaDigits()} $kg',
          ),
        ],
      ),
    );
  }
}

class _AveragesCard extends StatelessWidget {
  const _AveragesCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ProgressSectionCard(
      title: l10n.progressAvgPerDay,
      child: Column(
        children: <Widget>[
          _TotalsRow(
            leftLabel: l10n.progressChartCalories,
            leftValue:
                '${summary.avgCaloriesPerDay.round().toString().toBanglaDigits()} ${l10n.dashboardKcalUnit}',
            rightLabel: l10n.progressChartWorkoutMinutes,
            rightValue:
                '${summary.avgWorkoutMinutesPerDay.round().toString().toBanglaDigits()} ${l10n.progressUnitMin}',
          ),
          const Divider(height: 20),
          _TotalsRow(
            leftLabel: l10n.progressSummaryAvgSteps,
            leftValue:
                '${summary.avgStepsPerDay.toString().toBanglaDigits()} ${l10n.progressUnitSteps}',
            rightLabel: l10n.progressSummaryAvgWater,
            rightValue:
                '${summary.avgWaterMlPerDay.toString().toBanglaDigits()} ${l10n.progressUnitMl}',
          ),
          const Divider(height: 20),
          _TotalsRow(
            leftLabel: l10n.progressSummaryAvgSleep,
            leftValue:
                '${summary.avgSleepHoursPerDay.toStringAsFixed(1).toBanglaDigits()} ${l10n.progressUnitHours}',
            rightLabel: l10n.progressSummaryActiveDays,
            rightValue: summary.activeDays.toString().toBanglaDigits(),
          ),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _LabeledValue(label: leftLabel, value: leftValue),
        ),
        Expanded(
          child: _LabeledValue(label: rightLabel, value: rightValue),
        ),
      ],
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
    final String kcal = context.l10n.dashboardKcalUnit;
    final List<TrendPoint> points = <TrendPoint>[];
    for (int i = 0; i < report.series.length; i++) {
      final point = report.series[i];
      points.add(
        TrendPoint(
          x: i.toDouble(),
          y: point.caloriesBurned,
          label: point.label,
          tooltip:
              '${point.caloriesBurned.round().toString().toBanglaDigits()} $kcal',
        ),
      );
    }
    return TrendLineChart(points: points, color: colors.secondary);
  }
}

class _WorkoutMinutesChart extends StatelessWidget {
  const _WorkoutMinutesChart({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final AppColors colors =
        AppColors.light;
    final String min = context.l10n.progressUnitMin;
    final List<TrendPoint> points = <TrendPoint>[];
    for (int i = 0; i < report.series.length; i++) {
      final point = report.series[i];
      points.add(
        TrendPoint(
          x: i.toDouble(),
          y: point.workoutMinutes,
          label: point.label,
          tooltip:
              '${point.workoutMinutes.round().toString().toBanglaDigits()} $min',
        ),
      );
    }
    return AnalyticsBarChart(points: points, color: colors.primary);
  }
}

class _WorkoutCountChart extends StatelessWidget {
  const _WorkoutCountChart({required this.report});

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
          y: point.workoutCount.toDouble(),
          label: point.label,
          tooltip:
              '${point.workoutCount.toString().toBanglaDigits()} '
              '${context.l10n.progressUnitWorkouts}',
        ),
      );
    }
    return AnalyticsBarChart(points: points, color: colors.tertiary);
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

class _SleepChart extends StatelessWidget {
  const _SleepChart({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final AppColors colors =
        AppColors.light;
    final String hrs = context.l10n.progressUnitHours;
    final List<TrendPoint> points = <TrendPoint>[];
    for (int i = 0; i < report.series.length; i++) {
      final point = report.series[i];
      points.add(
        TrendPoint(
          x: i.toDouble(),
          y: point.sleepMinutes / 60,
          label: point.label,
          tooltip:
              '${(point.sleepMinutes / 60).toStringAsFixed(1).toBanglaDigits()} $hrs',
        ),
      );
    }
    return AnalyticsBarChart(points: points, color: colors.tertiary);
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

class _BmiChart extends StatelessWidget {
  const _BmiChart({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final AppColors colors =
        AppColors.light;
    final List<TrendPoint> points = <TrendPoint>[];
    for (int i = 0; i < report.series.length; i++) {
      final point = report.series[i];
      final double? bmi = point.bmi;
      if (bmi == null) continue;
      points.add(
        TrendPoint(
          x: i.toDouble(),
          y: bmi,
          label: point.label,
          tooltip: bmi.toStringAsFixed(1).toBanglaDigits(),
        ),
      );
    }
    return TrendLineChart(points: points, color: colors.info);
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.report});

  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors =
        AppColors.light;
    final double burned = report.summary.caloriesBurned;
    final double consumed = report.summary.caloriesConsumed;
    final bool hasData = burned > 0 || consumed > 0;

    return ProgressSectionCard(
      title: l10n.progressCalorieBalance,
      child: hasData
          ? Column(
              children: <Widget>[
                SizedBox(
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 40,
                      sectionsSpace: 3,
                      sections: <PieChartSectionData>[
                        PieChartSectionData(
                          value: consumed,
                          title:
                              consumed.round().toString().toBanglaDigits(),
                          color: colors.primary,
                          radius: 54,
                          titleStyle: context.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        PieChartSectionData(
                          value: burned,
                          title:
                              burned.round().toString().toBanglaDigits(),
                          color: colors.secondary,
                          radius: 54,
                          titleStyle: context.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _LegendChip(
                      color: colors.primary,
                      label: l10n.progressSummaryCaloriesConsumed,
                    ),
                    _LegendChip(
                      color: colors.secondary,
                      label: l10n.progressSummaryCaloriesBurned,
                    ),
                  ],
                ),
              ],
            )
          : Text(
              l10n.progressEmptyTitle,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
