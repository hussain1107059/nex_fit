import '../entities/weight_history.dart';
import '../entities/weight_log.dart';
import '../entities/weight_overview.dart';
import '../entities/weight_statistics.dart';

/// Aggregate contract for the weight tracker & body composition module.
///
/// Composes the weight log, BMI log, body measurements and the user's
/// physical profile so the UI can render computed metrics and charts.
abstract interface class WeightRepository {
  /// Full aggregate used by the weight tracker screen.
  Future<WeightOverview> loadOverview(String userId);

  /// Bucketed weight history for a [period] window.
  Future<WeightHistory> loadHistory(
    String userId,
    WeightHistoryPeriod period,
  );

  /// Lifetime weight statistics.
  Future<WeightStatistics> loadStatistics(String userId);

  /// The user's target weight in kg, if configured.
  Future<double?> getGoal(String userId);

  /// Persists a new target weight (kg).
  Future<void> setGoal(String userId, double goalKg);

  /// Logs a weight entry and, when the profile height is known, auto-inserts
  /// a matching BMI snapshot. Returns the created entry.
  Future<WeightLog> addWeight(
    String userId,
    double weightKg, {
    DateTime? date,
    String? note,
  });

  Future<void> updateWeight(WeightLog log);

  Future<void> deleteWeight(int id);
}
