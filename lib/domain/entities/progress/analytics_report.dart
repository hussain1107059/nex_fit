import 'package:equatable/equatable.dart';

import 'analytics_summary.dart';
import 'report_period.dart';

/// Bucket size used to build a report's time series.
enum AnalyticsGranularity { daily, weekly, monthly }

/// A single bucket of the report series (a day, week or month).
class AnalyticsDataPoint extends Equatable {
  const AnalyticsDataPoint({
    required this.date,
    required this.label,
    this.caloriesBurned = 0,
    this.caloriesConsumed = 0,
    this.workoutMinutes = 0,
    this.workoutCount = 0,
    this.waterMl = 0,
    this.steps = 0,
    this.sleepMinutes = 0,
    this.weightKg,
    this.bmi,
  });

  final DateTime date;

  /// Short localised label for the x axis.
  final String label;
  final double caloriesBurned;
  final double caloriesConsumed;
  final double workoutMinutes;
  final int workoutCount;
  final int waterMl;
  final int steps;
  final double sleepMinutes;
  final double? weightKg;
  final double? bmi;

  @override
  List<Object?> get props => [
        date,
        label,
        caloriesBurned,
        caloriesConsumed,
        workoutMinutes,
        workoutCount,
        waterMl,
        steps,
        sleepMinutes,
        weightKg,
        bmi,
      ];
}

/// The complete aggregate returned for a progress report window.
class AnalyticsReport extends Equatable {
  const AnalyticsReport({
    required this.period,
    required this.start,
    required this.end,
    required this.summary,
    required this.series,
    this.hasAnyData = true,
  });

  final ReportPeriod period;
  final DateTime start;
  final DateTime end;
  final AnalyticsSummary summary;
  final List<AnalyticsDataPoint> series;

  /// False when the user has no tracked data inside the window.
  final bool hasAnyData;

  @override
  List<Object?> get props =>
      [period, start, end, summary, series, hasAnyData];
}
