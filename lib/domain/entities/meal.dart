import 'package:equatable/equatable.dart';

/// A user-defined meal with its macro nutrients, grouped into a category.
class Meal extends Equatable {
  const Meal({
    this.id,
    required this.userId,
    this.categoryId,
    required this.name,
    this.description,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.image,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String userId;
  final int? categoryId;
  final String name;
  final String? description;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? image;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  Meal copyWith({
    int? id,
    String? userId,
    int? categoryId,
    String? name,
    String? description,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    String? image,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Meal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      image: image ?? this.image,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        categoryId,
        name,
        description,
        calories,
        protein,
        carbs,
        fat,
        image,
        isFavorite,
        createdAt,
        updatedAt,
      ];
}
