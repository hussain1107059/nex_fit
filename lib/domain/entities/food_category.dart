/// Global catalog of food categories used by the food database.
///
/// Stored on `food_item.category` as the lower-case [name] so filtering is a
/// plain string comparison.
enum FoodCategory {
  rice,
  bread,
  meat,
  chicken,
  fish,
  egg,
  vegetables,
  fruits,
  milk,
  dairy,
  fastFood,
  dessert,
  drinks,
  nuts,
  seeds,
  healthySnacks;

  static const List<FoodCategory> valuesInOrder = <FoodCategory>[
    FoodCategory.rice,
    FoodCategory.bread,
    FoodCategory.meat,
    FoodCategory.chicken,
    FoodCategory.fish,
    FoodCategory.egg,
    FoodCategory.vegetables,
    FoodCategory.fruits,
    FoodCategory.milk,
    FoodCategory.dairy,
    FoodCategory.fastFood,
    FoodCategory.dessert,
    FoodCategory.drinks,
    FoodCategory.nuts,
    FoodCategory.seeds,
    FoodCategory.healthySnacks,
  ];

  /// Resolves a stored slug back to its enum, defaulting to [FoodCategory.fruits].
  static FoodCategory fromName(String? value) {
    return FoodCategory.values.firstWhere(
      (FoodCategory category) => category.name == value,
      orElse: () => FoodCategory.fruits,
    );
  }
}
