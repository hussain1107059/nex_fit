import 'package:equatable/equatable.dart';

/// A food consumed at a point in time, optionally linked to a food/meal.
class FoodLog extends Equatable {
  const FoodLog({
    this.id,
    required this.userId,
    this.foodItemId,
    this.mealId,
    this.quantity = 1,
    this.servingSize,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    required this.loggedAt,
    required this.createdAt,
  });

  final int? id;
  final String userId;
  final int? foodItemId;
  final int? mealId;
  final double quantity;
  final String? servingSize;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime loggedAt;
  final DateTime createdAt;

  FoodLog copyWith({
    int? id,
    String? userId,
    int? foodItemId,
    int? mealId,
    double? quantity,
    String? servingSize,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    DateTime? loggedAt,
    DateTime? createdAt,
  }) {
    return FoodLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      foodItemId: foodItemId ?? this.foodItemId,
      mealId: mealId ?? this.mealId,
      quantity: quantity ?? this.quantity,
      servingSize: servingSize ?? this.servingSize,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
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
        quantity,
        servingSize,
        calories,
        protein,
        carbs,
        fat,
        loggedAt,
        createdAt,
      ];
}
