import 'package:equatable/equatable.dart';

import 'nutrition_day_summary.dart';

/// Nutrition history over a date range, with rolled-up aggregates.
class NutritionHistory extends Equatable {
  const NutritionHistory({
    required this.start,
    required this.end,
    this.days = const <NutritionDaySummary>[],
  });

  final DateTime start;
  final DateTime end;
  final List<NutritionDaySummary> days;

  double get totalCalories =>
      days.fold(0, (double sum, NutritionDaySummary day) => sum + day.calories);

  double get averageCalories =>
      days.isEmpty ? 0 : totalCalories / days.length;

  double get averageProtein =>
      days.isEmpty ? 0 : totalProtein / days.length;

  double get averageCarbs =>
      days.isEmpty ? 0 : totalCarbs / days.length;

  double get averageFat =>
      days.isEmpty ? 0 : totalFat / days.length;

  int get averageWater =>
      days.isEmpty ? 0 : totalWater ~/ days.length;

  double get totalProtein =>
      days.fold(0, (double sum, NutritionDaySummary day) => sum + day.protein);

  double get totalCarbs =>
      days.fold(0, (double sum, NutritionDaySummary day) => sum + day.carbs);

  double get totalFat =>
      days.fold(0, (double sum, NutritionDaySummary day) => sum + day.fat);

  int get totalWater =>
      days.fold(0, (int sum, NutritionDaySummary day) => sum + day.waterMl);

  int get loggedDays =>
      days.where((NutritionDaySummary day) => day.itemCount > 0).length;

  @override
  List<Object?> get props => [start, end, days];
}
