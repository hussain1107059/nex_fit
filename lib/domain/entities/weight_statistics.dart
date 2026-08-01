import 'package:equatable/equatable.dart';

/// Lifetime statistics derived from the user's weight log.
class WeightStatistics extends Equatable {
  const WeightStatistics({
    this.startWeightKg,
    this.currentWeightKg,
    this.minWeightKg,
    this.maxWeightKg,
    this.averageWeightKg,
    this.totalChangeKg,
    this.daysTracked = 0,
    this.totalEntries = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.firstDate,
    this.lastDate,
  });

  /// First logged weight.
  final double? startWeightKg;

  /// Most recent logged weight.
  final double? currentWeightKg;

  /// Lowest logged weight.
  final double? minWeightKg;

  /// Highest logged weight.
  final double? maxWeightKg;

  /// Mean of all logged weights.
  final double? averageWeightKg;

  /// current - start (negative means weight lost).
  final double? totalChangeKg;

  /// Distinct days with at least one entry.
  final int daysTracked;

  /// Total number of weight entries.
  final int totalEntries;

  /// Consecutive days with entries ending today (or yesterday).
  final int currentStreak;

  /// Longest run of consecutive logged days.
  final int longestStreak;

  final DateTime? firstDate;
  final DateTime? lastDate;

  bool get isEmpty => totalEntries == 0;

  @override
  List<Object?> get props => [
        startWeightKg,
        currentWeightKg,
        minWeightKg,
        maxWeightKg,
        averageWeightKg,
        totalChangeKg,
        daysTracked,
        totalEntries,
        currentStreak,
        longestStreak,
        firstDate,
        lastDate,
      ];
}
