import 'package:equatable/equatable.dart';

import 'water_log.dart';

/// How hydrated the user is relative to their daily goal.
enum HydrationStatus {
  needsWater,
  gettingThere,
  nearlyThere,
  goalMet,
  exceeded;

  static HydrationStatus fromRatio(double ratio, bool goalMet) {
    if (!goalMet) {
      if (ratio < 0.33) return HydrationStatus.needsWater;
      if (ratio < 0.66) return HydrationStatus.gettingThere;
      return HydrationStatus.nearlyThere;
    }
    return ratio > 1.0
        ? HydrationStatus.exceeded
        : HydrationStatus.goalMet;
  }
}

/// The water tracker's daily aggregate: intake, goal, progress and entries.
class DailyHydration extends Equatable {
  const DailyHydration({
    required this.date,
    required this.intakeMl,
    required this.goalMl,
    required this.entries,
  });

  final DateTime date;
  final int intakeMl;
  final int goalMl;
  final List<WaterLog> entries;

  int get remainingMl => (goalMl - intakeMl).clamp(0, 1 << 62);

  /// Intake / goal, clamped between 0 and 1 for progress visuals.
  double get ratio {
    if (goalMl <= 0) return 0;
    return (intakeMl / goalMl).clamp(0.0, 1.0);
  }

  bool get isGoalMet => goalMl > 0 && intakeMl >= goalMl;

  HydrationStatus get status =>
      HydrationStatus.fromRatio(goalMl <= 0 ? 0 : intakeMl / goalMl, isGoalMet);

  @override
  List<Object?> get props => [date, intakeMl, goalMl, entries];
}
