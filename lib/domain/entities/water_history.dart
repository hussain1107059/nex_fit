import 'package:equatable/equatable.dart';

/// Aggregation window shown by the water history screen.
enum WaterHistoryPeriod {
  daily,
  weekly,
  monthly,
  yearly;

  static WaterHistoryPeriod fromName(String? value) {
    return WaterHistoryPeriod.values.firstWhere(
      (period) => period.name == value,
      orElse: () => WaterHistoryPeriod.daily,
    );
  }
}

/// One bucketed chunk of the water history (a day, week, month or year).
class WaterHistoryBucket extends Equatable {
  const WaterHistoryBucket({
    required this.start,
    required this.end,
    required this.intakeMl,
  });

  final DateTime start;
  final DateTime end;
  final int intakeMl;

  @override
  List<Object?> get props => [start, end, intakeMl];
}

/// Water intake aggregated across a [WaterHistoryPeriod].
class WaterHistory extends Equatable {
  const WaterHistory({
    required this.period,
    required this.start,
    required this.end,
    required this.buckets,
  });

  final WaterHistoryPeriod period;
  final DateTime start;
  final DateTime end;
  final List<WaterHistoryBucket> buckets;

  int get totalMl {
    return buckets.fold(0, (int sum, WaterHistoryBucket b) => sum + b.intakeMl);
  }

  int get averageMl {
    if (buckets.isEmpty) return 0;
    return (totalMl / buckets.length).round();
  }

  int get bestMl {
    if (buckets.isEmpty) return 0;
    int best = 0;
    for (final WaterHistoryBucket bucket in buckets) {
      if (bucket.intakeMl > best) best = bucket.intakeMl;
    }
    return best;
  }

  int get loggedBuckets {
    return buckets.where((WaterHistoryBucket b) => b.intakeMl > 0).length;
  }

  @override
  List<Object?> get props => [period, start, end, buckets];
}
