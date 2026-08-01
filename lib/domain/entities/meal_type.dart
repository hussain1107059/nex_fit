/// The six meal slots of a day used by the meal planner and daily log.
///
/// The [slug] maps one-to-one onto the seeded `meal_category` rows so the
/// enum stays in sync with the shared catalog.
enum MealType {
  breakfast,
  morningSnack,
  lunch,
  eveningSnack,
  dinner,
  lateNightSnack;

  static const List<MealType> valuesInOrder = <MealType>[
    MealType.breakfast,
    MealType.morningSnack,
    MealType.lunch,
    MealType.eveningSnack,
    MealType.dinner,
    MealType.lateNightSnack,
  ];

  String get slug => switch (this) {
    MealType.breakfast => 'breakfast',
    MealType.morningSnack => 'morning_snack',
    MealType.lunch => 'lunch',
    MealType.eveningSnack => 'evening_snack',
    MealType.dinner => 'dinner',
    MealType.lateNightSnack => 'late_night_snack',
  };

  static MealType fromSlug(String? value) {
    return MealType.values.firstWhere(
      (MealType type) => type.slug == value,
      orElse: () => MealType.breakfast,
    );
  }
}
