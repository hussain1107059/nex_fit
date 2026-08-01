import 'package:equatable/equatable.dart';

import 'food_category.dart';

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
    this.sodium = 0,
    this.potassium = 0,
    this.calcium = 0,
    this.iron = 0,
    this.vitaminA = 0,
    this.vitaminC = 0,
    this.waterPercentage = 0,
    this.barcode,
    this.imagePath,
    this.isCustom = false,
    this.isFavorite = false,
    required this.createdAt,
  });

  final int? id;
  final String? userId;
  final String name;
  final String? brand;

  /// Raw category slug, resolved through [categoryEnum].
  final String? category;
  final String? servingSize;
  final double? servingGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;

  /// Micronutrients per serving (mg / mcg as stored on the catalog).
  final double sodium;
  final double potassium;
  final double calcium;
  final double iron;
  final double vitaminA;
  final double vitaminC;

  /// Water content as a percentage of a serving.
  final double waterPercentage;
  final String? barcode;
  final String? imagePath;
  final bool isCustom;
  final bool isFavorite;
  final DateTime createdAt;

  bool get isBuiltIn => userId == null;

  FoodCategory get categoryEnum => FoodCategory.fromName(category);

  /// Macro split of the serving as grams per 100 calories, used by charts.
  double get totalMacros => protein + carbs + fat;

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
    double? sodium,
    double? potassium,
    double? calcium,
    double? iron,
    double? vitaminA,
    double? vitaminC,
    double? waterPercentage,
    String? barcode,
    String? imagePath,
    bool? isCustom,
    bool? isFavorite,
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
      sodium: sodium ?? this.sodium,
      potassium: potassium ?? this.potassium,
      calcium: calcium ?? this.calcium,
      iron: iron ?? this.iron,
      vitaminA: vitaminA ?? this.vitaminA,
      vitaminC: vitaminC ?? this.vitaminC,
      waterPercentage: waterPercentage ?? this.waterPercentage,
      barcode: barcode ?? this.barcode,
      imagePath: imagePath ?? this.imagePath,
      isCustom: isCustom ?? this.isCustom,
      isFavorite: isFavorite ?? this.isFavorite,
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
        sodium,
        potassium,
        calcium,
        iron,
        vitaminA,
        vitaminC,
        waterPercentage,
        barcode,
        imagePath,
        isCustom,
        isFavorite,
        createdAt,
      ];
}
