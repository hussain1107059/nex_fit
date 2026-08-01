import '../entities/progress/analytics_report.dart';
import '../entities/progress/fitness_score.dart';
import '../entities/progress/goal_progress.dart';
import '../entities/progress/personal_record.dart';
import '../entities/progress/report_period.dart';

/// Contract for the Progress & Analytics module.
///
/// All data is aggregated from the user's real local records; nothing is
/// fabricated.
abstract interface class ProgressAnalyticsRepository {
  /// Loads the aggregated report for [period]. When [period] is [ReportPeriod.custom]
  /// the explicit [customStart]/[customEnd] bounds (inclusive start, exclusive end)
  /// are used.
  Future<AnalyticsReport> loadReport(
    String userId,
    ReportPeriod period, {
    DateTime? customStart,
    DateTime? customEnd,
  });

  /// Lifetime personal records for the user.
  Future<List<PersonalRecord>> loadPersonalRecords(String userId);

  /// Live progress towards the user's targets (weight, workout, calories,
  /// water, steps, sleep).
  Future<List<GoalProgress>> loadGoalProgress(String userId);

  /// Composite fitness score (0..100) with its component breakdown.
  Future<FitnessScore> loadFitnessScore(String userId);
}
