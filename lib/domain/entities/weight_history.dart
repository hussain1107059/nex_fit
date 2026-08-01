import 'package:equatable/equatable.dart';

/// Aggregation window used by the weight history and trend charts.
enum WeightHistoryPeriod {
  daily,
  weekly,
  monthly,
  yearly;

  static WeightHistoryPeriod fromName(String? value) {
    return WeightHistoryPeriod.values.firstWhere(
      (period) => period.name == value,
      orElse: () => WeightHistoryPeriod.daily,
    );
  }
}

/// A single bucket of the weight history, one per day/week/month/year.
class WeightHistoryBucket extends Equatable {
  const WeightHistoryBucket({
    required this.start,
    required this.end,
    required this.latestWeightKg,
    required this.firstWeightKg,
    required this.entries,
  });

  final DateTime start;
  final DateTime end;

  /// Most recent weight recorded inside the bucket (the trend point).
  final double latestWeightKg;

  /// Earliest weight recorded inside the bucket.
  final double firstWeightKg;

  /// Number of entries inside the bucket.
  final int entries;

  double get changeKg => latestWeightKg - firstWeightKg;

  @override
  List<Object?> get props =>
      [start, end, latestWeightKg, firstWeightKg, entries];
}

/// Bucketed weight history for a [WeightHistoryPeriod] window.
class WeightHistory extends Equatable {
  const WeightHistory({
    required this.period,
    required this.start,
    required this.end,
    required this.buckets,
  });

  final WeightHistoryPeriod period;
  final DateTime start;
  final DateTime end;
  final List<WeightHistoryBucket> buckets;

  /// Weight at the start of the window, or null when no data exists.
  double? get startWeight {
    for (final WeightHistoryBucket bucket in buckets) {
      if (bucket.entries > 0) return bucket.firstWeightKg;
    }
    return null;
  }

  /// Most recent weight inside the window, or null when no data exists.
  double? get latestWeight {
    for (final WeightHistoryBucket bucket in buckets.reversed) {
      if (bucket.entries > 0) return bucket.latestWeightKg;
    }
    return null;
  }

  /// Total change across the window (0 when empty).
  double get totalChange {
    final double? start = startWeight;
    final double? latest = latestWeight;
    if (start == null || latest == null) return 0;
    return latest - start;
  }

  /// Number of buckets with at least one entry.
  int get loggedBuckets => buckets.where((b) => b.entries > 0).length;

  @override
  List<Object?> get props => [period, start, end, buckets];
}
