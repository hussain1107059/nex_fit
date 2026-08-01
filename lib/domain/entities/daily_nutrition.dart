import 'package:equatable/equatable.dart';

import 'meal_slot.dart';

/// Aggregated nutrition state for a single calendar day.
///
/// Totals are derived from the day's [food_log] rows; targets come from the
/// user's profile. The [waterMl] is the day's logged water intake (read-only
/// integration with the water module).
class DailyNutrition extends Equatable {
  const DailyNutrition({
    required this.date,
    this.slots = const <MealSlot>[],
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.waterMl = 0,
    this.targetCalories = 0,
    this.targetProtein = 0,
    this.targetCarbs = 0,
    this.targetFat = 0,
    this.targetWaterMl = 0,
    this.isGoalMet = false,
  });

  final DateTime date;
  final List<MealSlot> slots;

  // Consumed totals.
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;

  // Water integration (read-only, no logging UI in this module).
  final int waterMl;

  // Targets from the user profile.
  final double targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final int targetWaterMl;

  final bool isGoalMet;

  int get itemCount =>
      slots.fold(0, (int sum, MealSlot slot) => sum + slot.itemCount);

  double get remainingCalories => (targetCalories - calories).clamp(0, double.infinity);

  double get caloriesRatio =>
      targetCalories <= 0 ? 0 : (calories / targetCalories).clamp(0.0, 1.0);

  double get waterRatio =>
      targetWaterMl <= 0 ? 0 : (waterMl / targetWaterMl).clamp(0.0, 1.0);

  /// Protein share of total macro grams (0-1).
  double get proteinRatio {
    final double total = protein + carbs + fat;
    if (total <= 0) return 0;
    return (protein / total).clamp(0.0, 1.0);
  }

  double get carbsRatio {
    final double total = protein + carbs + fat;
    if (total <= 0) return 0;
    return (carbs / total).clamp(0.0, 1.0);
  }

  double get fatRatio {
    final double total = protein + carbs + fat;
    if (total <= 0) return 0;
    return (fat / total).clamp(0.0, 1.0);
  }

  /// Macro goal adherence (consumed vs target, capped at 1).
  double get proteinGoalRatio =>
      targetProtein <= 0 ? 0 : (protein / targetProtein).clamp(0.0, 1.0);

  double get carbsGoalRatio =>
      targetCarbs <= 0 ? 0 : (carbs / targetCarbs).clamp(0.0, 1.0);

  double get fatGoalRatio =>
      targetFat <= 0 ? 0 : (fat / targetFat).clamp(0.0, 1.0);

  DailyNutrition copyWith({
    DateTime? date,
    List<MealSlot>? slots,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
    int? waterMl,
    double? targetCalories,
    double? targetProtein,
    double? targetCarbs,
    double? targetFat,
    int? targetWaterMl,
    bool? isGoalMet,
  }) {
    return DailyNutrition(
      date: date ?? this.date,
      slots: slots ?? this.slots,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      waterMl: waterMl ?? this.waterMl,
      targetCalories: targetCalories ?? this.targetCalories,
      targetProtein: targetProtein ?? this.targetProtein,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      targetFat: targetFat ?? this.targetFat,
      targetWaterMl: targetWaterMl ?? this.targetWaterMl,
      isGoalMet: isGoalMet ?? this.isGoalMet,
    );
  }

  @override
  List<Object?> get props => [
        date,
        slots,
        calories,
        protein,
        carbs,
        fat,
        fiber,
        sugar,
        waterMl,
        targetCalories,
        targetProtein,
        targetCarbs,
        targetFat,
        targetWaterMl,
        isGoalMet,
      ];
}
