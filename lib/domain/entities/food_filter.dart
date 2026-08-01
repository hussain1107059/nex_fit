import 'package:equatable/equatable.dart';

import 'food_category.dart';

/// Search criteria for the food database.
class FoodFilter extends Equatable {
  const FoodFilter({
    this.query = '',
    this.category,
    this.favoritesOnly = false,
    this.maxCalories,
    this.minProtein,
  });

  final String query;
  final FoodCategory? category;
  final bool favoritesOnly;
  final double? maxCalories;
  final double? minProtein;

  bool get isEmpty =>
      query.trim().isEmpty &&
      category == null &&
      !favoritesOnly &&
      maxCalories == null &&
      minProtein == null;

  FoodFilter copyWith({
    String? query,
    FoodCategory? category,
    bool? favoritesOnly,
    double? maxCalories,
    double? minProtein,
  }) {
    return FoodFilter(
      query: query ?? this.query,
      category: category ?? this.category,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      maxCalories: maxCalories ?? this.maxCalories,
      minProtein: minProtein ?? this.minProtein,
    );
  }

  @override
  List<Object?> get props => [
        query,
        category,
        favoritesOnly,
        maxCalories,
        minProtein,
      ];
}
