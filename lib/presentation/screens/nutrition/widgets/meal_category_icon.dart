import 'package:flutter/material.dart';

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
