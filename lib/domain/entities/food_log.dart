import 'package:equatable/equatable.dart';

/// A food consumed at a point in time, optionally linked to a food/meal.
///
/// [calories], [protein], [carbs], [fat], [fiber] and [sugar] are snapshot
/// values already scaled by [quantity] so daily aggregation is a plain sum.
class FoodLog extends Equatable {
  const FoodLog({
    this.id,
    required this.userId,
    this.foodItemId,
    this.mealId,
    this.mealTypeId,
    this.quantity = 1,
    this.servingSize,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
    required this.loggedAt,
    required this.createdAt,
  });

  final int? id;
  final String userId;
  final int? foodItemId;
  final int? mealId;

  /// The meal slot this log belongs to (`meal_category.id`).
  final int? mealTypeId;
  final double quantity;
  final String? servingSize;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final DateTime loggedAt;
  final DateTime createdAt;

  FoodLog copyWith({
    int? id,
    String? userId,
    int? foodItemId,
    int? mealId,
    int? mealTypeId,
    double? quantity,
    String? servingSize,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
    DateTime? loggedAt,
    DateTime? createdAt,
  }) {
    return FoodLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      foodItemId: foodItemId ?? this.foodItemId,
      mealId: mealId ?? this.mealId,
      mealTypeId: mealTypeId ?? this.mealTypeId,
      quantity: quantity ?? this.quantity,
      servingSize: servingSize ?? this.servingSize,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        foodItemId,
        mealId,
        mealTypeId,
        quantity,
        servingSize,
        calories,
        protein,
        carbs,
        fat,
        fiber,
        sugar,
        loggedAt,
        createdAt,
      ];
}
