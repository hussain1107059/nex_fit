import '../../domain/entities/sleep_log.dart';

/// Derived averages over a list of sleep records.
class SleepStats {
  const SleepStats({
    required this.nights,
    required this.avgDurationMinutes,
    required this.avgQuality,
  });

  final int nights;
  final double avgDurationMinutes;
  final double avgQuality;

  static const SleepStats empty = SleepStats(
    nights: 0,
    avgDurationMinutes: 0,
    avgQuality: 0,
  );

  /// Computes the averages over [logs]. Quality averages 0..5.
  static SleepStats from(List<SleepLog> logs) {
    if (logs.isEmpty) return SleepStats.empty;
    final int nights = logs.length;
    final double avgDuration =
        logs.fold<double>(0, (double sum, SleepLog l) => sum + l.durationMinutes) /
        nights;
    final double avgQuality =
        logs.fold<double>(0, (double sum, SleepLog l) => sum + l.quality) / nights;
    return SleepStats(
      nights: nights,
      avgDurationMinutes: avgDuration,
      avgQuality: avgQuality,
    );
  }
}