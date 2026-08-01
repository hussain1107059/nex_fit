import 'package:equatable/equatable.dart';

/// Aggregated macros for a single day, used by the history screen.
class NutritionDaySummary extends Equatable {
  const NutritionDaySummary({
    required this.date,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.waterMl = 0,
    this.itemCount = 0,
  });

  final DateTime date;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final int waterMl;
  final int itemCount;

  NutritionDaySummary copyWith({
    DateTime? date,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
    int? waterMl,
    int? itemCount,
  }) {
    return NutritionDaySummary(
      date: date ?? this.date,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      waterMl: waterMl ?? this.waterMl,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  @override
  List<Object?> get props => [
        date,
        calories,
        protein,
        carbs,
        fat,
        fiber,
        sugar,
        waterMl,
        itemCount,
      ];
}
