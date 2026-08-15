import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../domain/entities/meal_category.dart';

/// Icon for a meal category, keyed by its slug.
IconData mealCategoryIcon(String? slug) => switch (slug) {
  'breakfast' => Icons.breakfast_dining_rounded,
  'morning_snack' => Icons.free_breakfast_rounded,
  'lunch' => Icons.lunch_dining_rounded,
  'evening_snack' => Icons.local_cafe_rounded,
  'dinner' => Icons.dinner_dining_rounded,
  'late_night_snack' => Icons.nightlight_round,
  _ => Icons.restaurant_rounded,
};

/// Localized label for a meal category, keyed by its slug so the DB-stored
/// English names never leak into the UI. Falls back to the raw name for any
/// unknown/custom slug.
String mealCategoryLabel(MealCategory category, AppLocalizations l10n) {
  switch (category.slug) {
    case 'breakfast':
      return l10n.mealCategoryBreakfast;
    case 'morning_snack':
      return l10n.mealCategoryMorningSnack;
    case 'lunch':
      return l10n.mealCategoryLunch;
    case 'evening_snack':
      return l10n.mealCategoryEveningSnack;
    case 'dinner':
      return l10n.mealCategoryDinner;
    case 'late_night_snack':
      return l10n.mealCategoryLateNightSnack;
    default:
      return category.name;
  }
}
