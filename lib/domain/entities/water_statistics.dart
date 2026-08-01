import 'package:equatable/equatable.dart';

/// Lifetime hydration statistics computed from the local water log.
class WaterStatistics extends Equatable {
  const WaterStatistics({
    required this.averageDailyMl,
    this.bestDay,
    required this.bestDayMl,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalMl,
    required this.totalEntries,
    required this.trackedDays,
  });

  /// Total intake divided by the number of distinct days with entries.
  final int averageDailyMl;

  /// Calendar date with the highest single-day intake (null when no entries).
  final DateTime? bestDay;
  final int bestDayMl;

  /// Consecutive days (up to today) where the daily goal was met.
  final int currentStreak;

  /// Longest run of consecutive goal-met days on record.
  final int longestStreak;

  /// Lifetime volume of water consumed in ml.
  final int totalMl;
  final int totalEntries;
  final int trackedDays;

  @override
  List<Object?> get props => [
        averageDailyMl,
        bestDay,
        bestDayMl,
        currentStreak,
        longestStreak,
        totalMl,
        totalEntries,
        trackedDays,
      ];
}
