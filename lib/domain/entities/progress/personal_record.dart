import 'package:equatable/equatable.dart';

/// The kinds of lifetime personal records tracked by the app.
enum RecordKind {
  longestWorkout,
  highestCalories,
  fastestWorkout,
  longestStreak,
  bestWeek,
  bestMonth,
  mostActiveDay,
}

/// A single lifetime best (longest workout, best week, most active day...).
class PersonalRecord extends Equatable {
  const PersonalRecord({
    required this.kind,
    this.value,
    this.unit,
    this.occurredOn,
    this.weekStart,
    this.monthStart,
    this.activeDay,
  });

  final RecordKind kind;

  /// Numeric value of the record (minutes, kcal, days...).
  final double? value;

  /// Display unit of [value] (e.g. `min`, `kcal`).
  final String? unit;

  /// When the record happened (workouts / most active day).
  final DateTime? occurredOn;

  /// First day of the best week (Mon-Sun).
  final DateTime? weekStart;

  /// First day of the best month.
  final DateTime? monthStart;

  /// The single most active tracked day.
  final DateTime? activeDay;

  @override
  List<Object?> get props => [
        kind,
        value,
        unit,
        occurredOn,
        weekStart,
        monthStart,
        activeDay,
      ];
}
