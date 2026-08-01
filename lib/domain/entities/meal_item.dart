import 'package:equatable/equatable.dart';

/// A food inside a saved meal template, with its portion.
class MealItem extends Equatable {
  const MealItem({
    this.id,
    required this.mealId,
    required this.foodItemId,
    this.quantity = 1,
    this.sortOrder = 0,
  });

  final int? id;
  final int mealId;
  final int foodItemId;
  final double quantity;
  final int sortOrder;

  MealItem copyWith({
    int? id,
    int? mealId,
    int? foodItemId,
    double? quantity,
    int? sortOrder,
  }) {
    return MealItem(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      foodItemId: foodItemId ?? this.foodItemId,
      quantity: quantity ?? this.quantity,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [id, mealId, foodItemId, quantity, sortOrder];
}
