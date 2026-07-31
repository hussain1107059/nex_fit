import 'package:equatable/equatable.dart';

/// A food with per-serving nutrition. Built-in foods have a null [userId];
/// user-created foods carry the owner's account id.
class FoodItem extends Equatable {
  const FoodItem({
    this.id,
    this.userId,
    required this.name,
    this.brand,
    this.category,
    this.servingSize,
    this.servingGrams,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.isCustom = false,
    required this.createdAt,
  });

  final int? id;
  final String? userId;
  final String name;
  final String? brand;
  final String? category;
  final String? servingSize;
  final double? servingGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final bool isCustom;
  final DateTime createdAt;

  bool get isBuiltIn => userId == null;

  FoodItem copyWith({
    int? id,
    String? userId,
    String? name,
    String? brand,
    String? category,
    String? servingSize,
    double? servingGrams,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
    bool? isCustom,
    DateTime? createdAt,
  }) {
    return FoodItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      servingSize: servingSize ?? this.servingSize,
      servingGrams: servingGrams ?? this.servingGrams,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        brand,
        category,
        servingSize,
        servingGrams,
        calories,
        protein,
        carbs,
        fat,
        fiber,
        sugar,
        isCustom,
        createdAt,
      ];
}
