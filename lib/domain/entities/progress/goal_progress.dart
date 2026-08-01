import 'package:equatable/equatable.dart';

/// The habits a user can set a target for.
enum GoalKind {
  weight,
  workout,
  calories,
  water,
  steps,
  sleep,
}

/// Live progress towards a fitness target backed by real local records.
class GoalProgress extends Equatable {
  const GoalProgress({
    required this.kind,
    required this.title,
    required this.current,
    required this.target,
    required this.unit,
    this.start,
    this.hasTarget = true,
    this.targetDate,
  });

  final GoalKind kind;
  final String title;
  final double current;
  final double target;
  final String unit;

  /// Starting value for directional goals such as weight (used to compute
  /// progress from start towards [target]).
  final double? start;

  /// False when no target is configured (goal not set yet).
  final bool hasTarget;

  /// Optional deadline used to estimate days remaining.
  final DateTime? targetDate;

  /// Fraction of the target reached, clamped to 0..1.
  double get fraction {
    if (target <= 0) return 0;
    final double? s = start;
    if (s != null && s != target) {
      if (target < s) return ((s - current) / (s - target)).clamp(0.0, 1.0);
      return ((current - s) / (target - s)).clamp(0.0, 1.0);
    }
    return (current / target).clamp(0.0, 1.0);
  }

  /// Percentage reached (0..100).
  double get percent => fraction * 100;

  /// How much is left to reach the target.
  double get remaining {
    if (target <= 0) return 0;
    final double? s = start;
    if (s != null) return (target - current).abs();
    return (target - current).clamp(0.0, double.infinity);
  }

  /// Days left until [targetDate] (0 when passed or unknown).
  int get daysLeft {
    final DateTime? date = targetDate;
    if (date == null) return 0;
    final int days = date.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  @override
  List<Object?> get props => [
        kind,
        title,
        current,
        target,
        unit,
        start,
        hasTarget,
        targetDate,
      ];
}
