import '../../domain/entities/food_category.dart';

/// A single entry in the built-in food database catalog.
///
/// Minerals (sodium, potassium, calcium, iron) are in mg, vitamin A in mcg RE
/// and vitamin C in mg, all per the stated serving size.
class SeedFood {
  const SeedFood({
    required this.name,
    required this.category,
    required this.servingSize,
    required this.servingGrams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
    this.sugar = 0,
    this.sodium = 0,
    this.potassium = 0,
    this.calcium = 0,
    this.iron = 0,
    this.vitaminA = 0,
    this.vitaminC = 0,
    this.waterPercentage = 0,
  });

  final String name;
  final FoodCategory category;
  final String servingSize;
  final double servingGrams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double sugar;
  final double sodium;
  final double potassium;
  final double calcium;
  final double iron;
  final double vitaminA;
  final double vitaminC;
  final double waterPercentage;
}

/// 200+ built-in foods covering the full category catalog.
const List<SeedFood> kSeedFoods = <SeedFood>[
  // Rice
  SeedFood(name: 'White Rice (Cooked)', category: FoodCategory.rice, servingSize: '1 cup (150g)', servingGrams: 150, calories: 205, protein: 4.3, carbs: 45, fat: 0.4, fiber: 0.6, sugar: 0.1, sodium: 2, potassium: 55, calcium: 15, iron: 1.9, waterPercentage: 69),
  SeedFood(name: 'Brown Rice (Cooked)', category: FoodCategory.rice, servingSize: '1 cup (150g)', servingGrams: 150, calories: 218, protein: 4.5, carbs: 46, fat: 1.6, fiber: 3.5, sugar: 0.7, sodium: 8, potassium: 154, calcium: 15, iron: 1.0, waterPercentage: 70),
  SeedFood(name: 'Basmati Rice (Cooked)', category: FoodCategory.rice, servingSize: '1 cup (140g)', servingGrams: 140, calories: 190, protein: 4.1, carbs: 41, fat: 0.4, fiber: 0.7, sugar: 0.1, sodium: 2, potassium: 42, calcium: 12, iron: 0.9, waterPercentage: 69),
  SeedFood(name: 'Jasmine Rice (Cooked)', category: FoodCategory.rice, servingSize: '1 cup (140g)', servingGrams: 140, calories: 181, protein: 3.7, carbs: 39, fat: 0.3, fiber: 0.3, sugar: 0, sodium: 2, potassium: 34, calcium: 11, iron: 0.8, waterPercentage: 69),
  SeedFood(name: 'Fried Rice', category: FoodCategory.rice, servingSize: '1 cup (160g)', servingGrams: 160, calories: 238, protein: 5, carbs: 45, fat: 4.5, fiber: 1.5, sugar: 1, sodium: 620, potassium: 120, calcium: 18, iron: 1.3, waterPercentage: 62),
  SeedFood(name: 'Rice Porridge (Khichuri)', category: FoodCategory.rice, servingSize: '1 bowl (250g)', servingGrams: 250, calories: 210, protein: 7, carbs: 36, fat: 4, fiber: 2.5, sugar: 1, sodium: 480, potassium: 180, calcium: 20, iron: 1.8, waterPercentage: 74),
  SeedFood(name: 'Chicken Biryani', category: FoodCategory.rice, servingSize: '1 plate (350g)', servingGrams: 350, calories: 540, protein: 26, carbs: 60, fat: 22, fiber: 2, sugar: 2, sodium: 850, potassium: 350, calcium: 35, iron: 2.4, waterPercentage: 58),
  SeedFood(name: 'Vegetable Pulao', category: FoodCategory.rice, servingSize: '1 cup (160g)', servingGrams: 160, calories: 220, protein: 4.5, carbs: 40, fat: 5, fiber: 2, sugar: 1.5, sodium: 420, potassium: 150, calcium: 18, iron: 1.4, waterPercentage: 62),
  SeedFood(name: 'Rice Noodles', category: FoodCategory.rice, servingSize: '1 cup (180g)', servingGrams: 180, calories: 192, protein: 3.2, carbs: 44, fat: 0.4, fiber: 1.8, sugar: 0.5, sodium: 10, potassium: 34, calcium: 12, iron: 0.7, waterPercentage: 71),
  SeedFood(name: 'Rice Cake', category: FoodCategory.rice, servingSize: '1 piece (9g)', servingGrams: 9, calories: 35, protein: 0.7, carbs: 7, fat: 0.3, fiber: 0.4, sugar: 0, sodium: 30, potassium: 10, calcium: 1, iron: 0.1, waterPercentage: 6),
  SeedFood(name: 'Black Rice (Cooked)', category: FoodCategory.rice, servingSize: '1 cup (150g)', servingGrams: 150, calories: 200, protein: 5, carbs: 43, fat: 1.5, fiber: 3, sugar: 0.5, sodium: 5, potassium: 120, calcium: 13, iron: 1.6, waterPercentage: 70),
  SeedFood(name: 'Wild Rice (Cooked)', category: FoodCategory.rice, servingSize: '1 cup (165g)', servingGrams: 165, calories: 166, protein: 6.5, carbs: 35, fat: 0.6, fiber: 3, sugar: 1, sodium: 5, potassium: 170, calcium: 7, iron: 0.9, waterPercentage: 75),
  SeedFood(name: 'Sticky Rice (Cooked)', category: FoodCategory.rice, servingSize: '1 cup (150g)', servingGrams: 150, calories: 170, protein: 3.2, carbs: 37, fat: 0.3, fiber: 1, sugar: 0.1, sodium: 5, potassium: 25, calcium: 8, iron: 0.5, waterPercentage: 60),

  // Bread
  SeedFood(name: 'White Bread', category: FoodCategory.bread, servingSize: '1 slice (25g)', servingGrams: 25, calories: 67, protein: 2, carbs: 13, fat: 0.8, fiber: 0.6, sugar: 1.4, sodium: 130, potassium: 25, calcium: 35, iron: 0.9, waterPercentage: 36),
  SeedFood(name: 'Whole Wheat Bread', category: FoodCategory.bread, servingSize: '1 slice (28g)', servingGrams: 28, calories: 69, protein: 3.6, carbs: 12, fat: 1.1, fiber: 1.9, sugar: 1.4, sodium: 130, potassium: 69, calcium: 30, iron: 0.7, waterPercentage: 38),
  SeedFood(name: 'Brown Bread', category: FoodCategory.bread, servingSize: '1 slice (26g)', servingGrams: 26, calories: 66, protein: 2.5, carbs: 12, fat: 0.9, fiber: 1.2, sugar: 1.3, sodium: 125, potassium: 45, calcium: 32, iron: 0.8, waterPercentage: 38),
  SeedFood(name: 'Multigrain Bread', category: FoodCategory.bread, servingSize: '1 slice (28g)', servingGrams: 28, calories: 70, protein: 3.4, carbs: 12, fat: 1.1, fiber: 2, sugar: 1.3, sodium: 120, potassium: 60, calcium: 28, iron: 0.8, waterPercentage: 37),
  SeedFood(name: 'Rye Bread', category: FoodCategory.bread, servingSize: '1 slice (32g)', servingGrams: 32, calories: 83, protein: 2.7, carbs: 15, fat: 1.1, fiber: 2.2, sugar: 1.3, sodium: 151, potassium: 54, calcium: 10, iron: 0.7, waterPercentage: 38),
  SeedFood(name: 'Pita Bread', category: FoodCategory.bread, servingSize: '1 piece (60g)', servingGrams: 60, calories: 165, protein: 5.5, carbs: 33, fat: 0.7, fiber: 1.4, sugar: 0.5, sodium: 300, potassium: 70, calcium: 25, iron: 1.3, waterPercentage: 30),
  SeedFood(name: 'Naan', category: FoodCategory.bread, servingSize: '1 piece (90g)', servingGrams: 90, calories: 260, protein: 9, carbs: 45, fat: 5, fiber: 2, sugar: 3, sodium: 350, potassium: 90, calcium: 40, iron: 1.5, waterPercentage: 32),
  SeedFood(name: 'Roti (Chapati)', category: FoodCategory.bread, servingSize: '1 piece (40g)', servingGrams: 40, calories: 120, protein: 3.5, carbs: 24, fat: 1, fiber: 3, sugar: 0.3, sodium: 200, potassium: 60, calcium: 10, iron: 1, waterPercentage: 30),
  SeedFood(name: 'Paratha', category: FoodCategory.bread, servingSize: '1 piece (55g)', servingGrams: 55, calories: 240, protein: 4, carbs: 28, fat: 13, fiber: 1.5, sugar: 0.5, sodium: 330, potassium: 60, calcium: 12, iron: 1.1, waterPercentage: 25),
  SeedFood(name: 'Bagel', category: FoodCategory.bread, servingSize: '1 piece (100g)', servingGrams: 100, calories: 257, protein: 10, carbs: 50, fat: 1.5, fiber: 2, sugar: 5, sodium: 440, potassium: 90, calcium: 20, iron: 2.4, waterPercentage: 35),
  SeedFood(name: 'Croissant', category: FoodCategory.bread, servingSize: '1 piece (57g)', servingGrams: 57, calories: 231, protein: 5, carbs: 26, fat: 12, fiber: 1.5, sugar: 6, sodium: 260, potassium: 70, calcium: 20, iron: 1.2, waterPercentage: 25),
  SeedFood(name: 'Burger Bun', category: FoodCategory.bread, servingSize: '1 piece (50g)', servingGrams: 50, calories: 140, protein: 4.5, carbs: 26, fat: 2.5, fiber: 1.2, sugar: 4, sodium: 260, potassium: 50, calcium: 40, iron: 1.2, waterPercentage: 33),
  SeedFood(name: 'Gluten Free Bread', category: FoodCategory.bread, servingSize: '1 slice (30g)', servingGrams: 30, calories: 80, protein: 1.5, carbs: 15, fat: 1.5, fiber: 1, sugar: 1.5, sodium: 140, potassium: 20, calcium: 25, iron: 0.4, waterPercentage: 40),

  // Meat
  SeedFood(name: 'Beef Steak', category: FoodCategory.meat, servingSize: '100g', servingGrams: 100, calories: 271, protein: 25, carbs: 0, fat: 19, fiber: 0, sugar: 0, sodium: 60, potassium: 340, calcium: 12, iron: 2.6, waterPercentage: 60),
  SeedFood(name: 'Lean Ground Beef', category: FoodCategory.meat, servingSize: '100g', servingGrams: 100, calories: 250, protein: 26, carbs: 0, fat: 15, fiber: 0, sugar: 0, sodium: 75, potassium: 330, calcium: 14, iron: 2.4, waterPercentage: 62),
  SeedFood(name: 'Beef Curry', category: FoodCategory.meat, servingSize: '1 bowl (200g)', servingGrams: 200, calories: 350, protein: 28, carbs: 8, fat: 22, fiber: 1.5, sugar: 2, sodium: 700, potassium: 400, calcium: 25, iron: 3.2, waterPercentage: 60),
  SeedFood(name: 'Beef Liver', category: FoodCategory.meat, servingSize: '100g', servingGrams: 100, calories: 175, protein: 26, carbs: 5, fat: 4, fiber: 0, sugar: 0, sodium: 69, potassium: 310, calcium: 6, iron: 6.5, vitaminA: 7740, vitaminC: 1, waterPercentage: 69),
  SeedFood(name: 'Lamb Chop', category: FoodCategory.meat, servingSize: '100g', servingGrams: 100, calories: 294, protein: 25, carbs: 0, fat: 21, fiber: 0, sugar: 0, sodium: 65, potassium: 290, calcium: 17, iron: 1.9, waterPercentage: 58),
  SeedFood(name: 'Lamb Curry', category: FoodCategory.meat, servingSize: '1 bowl (200g)', servingGrams: 200, calories: 380, protein: 30, carbs: 9, fat: 25, fiber: 1.5, sugar: 2, sodium: 680, potassium: 380, calcium: 30, iron: 2.8, waterPercentage: 58),
  SeedFood(name: 'Pork Chop', category: FoodCategory.meat, servingSize: '100g', servingGrams: 100, calories: 231, protein: 25, carbs: 0, fat: 14, fiber: 0, sugar: 0, sodium: 62, potassium: 320, calcium: 15, iron: 0.8, waterPercentage: 58),
  SeedFood(name: 'Pork Bacon', category: FoodCategory.meat, servingSize: '2 slices (20g)', servingGrams: 20, calories: 90, protein: 6, carbs: 0.3, fat: 7, fiber: 0, sugar: 0.2, sodium: 350, potassium: 65, calcium: 2, iron: 0.3, waterPercentage: 30),
  SeedFood(name: 'Mutton Curry', category: FoodCategory.meat, servingSize: '1 bowl (200g)', servingGrams: 200, calories: 360, protein: 29, carbs: 8, fat: 24, fiber: 1.5, sugar: 2, sodium: 700, potassium: 360, calcium: 28, iron: 3.5, waterPercentage: 57),
  SeedFood(name: 'Beef Kebab', category: FoodCategory.meat, servingSize: '1 skewer (80g)', servingGrams: 80, calories: 210, protein: 18, carbs: 2, fat: 14, fiber: 0.5, sugar: 0.5, sodium: 480, potassium: 240, calcium: 10, iron: 2.2, waterPercentage: 58),
  SeedFood(name: 'Veal', category: FoodCategory.meat, servingSize: '100g', servingGrams: 100, calories: 172, protein: 31, carbs: 0, fat: 5, fiber: 0, sugar: 0, sodium: 86, potassium: 320, calcium: 9, iron: 0.9, waterPercentage: 68),
  SeedFood(name: 'Pork Sausage', category: FoodCategory.meat, servingSize: '1 link (75g)', servingGrams: 75, calories: 260, protein: 13, carbs: 2, fat: 22, fiber: 0, sugar: 1, sodium: 620, potassium: 150, calcium: 15, iron: 0.9, waterPercentage: 52),
  SeedFood(name: 'Ham', category: FoodCategory.meat, servingSize: '100g', servingGrams: 100, calories: 145, protein: 20, carbs: 1.5, fat: 5.5, fiber: 0, sugar: 1, sodium: 1000, potassium: 290, calcium: 8, iron: 1.2, waterPercentage: 65),
  SeedFood(name: 'Corned Beef', category: FoodCategory.meat, servingSize: '100g', servingGrams: 100, calories: 251, protein: 22, carbs: 0, fat: 18, fiber: 0, sugar: 0, sodium: 970, potassium: 250, calcium: 9, iron: 2.6, waterPercentage: 55),

  // Chicken
  SeedFood(name: 'Chicken Breast (Grilled)', category: FoodCategory.chicken, servingSize: '100g', servingGrams: 100, calories: 165, protein: 31, carbs: 0, fat: 3.6, fiber: 0, sugar: 0, sodium: 74, potassium: 340, calcium: 15, iron: 1, waterPercentage: 65),
  SeedFood(name: 'Chicken Thigh (Roasted)', category: FoodCategory.chicken, servingSize: '100g', servingGrams: 100, calories: 209, protein: 26, carbs: 0, fat: 11, fiber: 0, sugar: 0, sodium: 86, potassium: 280, calcium: 12, iron: 1.3, waterPercentage: 62),
  SeedFood(name: 'Chicken Drumstick', category: FoodCategory.chicken, servingSize: '1 piece (90g)', servingGrams: 90, calories: 165, protein: 21, carbs: 0, fat: 8, fiber: 0, sugar: 0, sodium: 90, potassium: 210, calcium: 10, iron: 1.1, waterPercentage: 62),
  SeedFood(name: 'Chicken Wing', category: FoodCategory.chicken, servingSize: '1 piece (60g)', servingGrams: 60, calories: 146, protein: 12, carbs: 0, fat: 10, fiber: 0, sugar: 0, sodium: 80, potassium: 140, calcium: 8, iron: 0.8, waterPercentage: 56),
  SeedFood(name: 'Chicken Curry', category: FoodCategory.chicken, servingSize: '1 bowl (200g)', servingGrams: 200, calories: 310, protein: 28, carbs: 7, fat: 18, fiber: 1, sugar: 2, sodium: 650, potassium: 380, calcium: 24, iron: 1.8, waterPercentage: 60),
  SeedFood(name: 'Butter Chicken', category: FoodCategory.chicken, servingSize: '1 bowl (250g)', servingGrams: 250, calories: 500, protein: 32, carbs: 12, fat: 36, fiber: 1, sugar: 6, sodium: 800, potassium: 380, calcium: 80, iron: 2.2, waterPercentage: 55),
  SeedFood(name: 'Chicken Tikka', category: FoodCategory.chicken, servingSize: '100g', servingGrams: 100, calories: 190, protein: 25, carbs: 4, fat: 8, fiber: 0.5, sugar: 2, sodium: 520, potassium: 300, calcium: 22, iron: 1.4, waterPercentage: 62),
  SeedFood(name: 'Chicken Kebab', category: FoodCategory.chicken, servingSize: '1 skewer (80g)', servingGrams: 80, calories: 160, protein: 20, carbs: 2, fat: 8, fiber: 0.3, sugar: 0.5, sodium: 400, potassium: 220, calcium: 12, iron: 1.1, waterPercentage: 62),
  SeedFood(name: 'Chicken Liver', category: FoodCategory.chicken, servingSize: '100g', servingGrams: 100, calories: 185, protein: 25, carbs: 1, fat: 8, fiber: 0, sugar: 0, sodium: 70, potassium: 250, calcium: 10, iron: 8, vitaminA: 3600, vitaminC: 17, waterPercentage: 68),
  SeedFood(name: 'Fried Chicken', category: FoodCategory.chicken, servingSize: '1 piece (120g)', servingGrams: 120, calories: 320, protein: 20, carbs: 12, fat: 22, fiber: 0.5, sugar: 1, sodium: 480, potassium: 220, calcium: 20, iron: 1.2, waterPercentage: 45),
  SeedFood(name: 'Chicken Biryani (Leg Piece)', category: FoodCategory.chicken, servingSize: '1 plate (350g)', servingGrams: 350, calories: 520, protein: 24, carbs: 62, fat: 20, fiber: 2, sugar: 2, sodium: 820, potassium: 340, calcium: 32, iron: 2.2, waterPercentage: 58),
  SeedFood(name: 'Chicken Soup', category: FoodCategory.chicken, servingSize: '1 bowl (240g)', servingGrams: 240, calories: 120, protein: 10, carbs: 8, fat: 5, fiber: 0.5, sugar: 1, sodium: 600, potassium: 200, calcium: 15, iron: 0.9, waterPercentage: 88),

  // Fish
  SeedFood(name: 'Salmon (Grilled)', category: FoodCategory.fish, servingSize: '100g', servingGrams: 100, calories: 208, protein: 20, carbs: 0, fat: 13, fiber: 0, sugar: 0, sodium: 59, potassium: 363, calcium: 9, iron: 0.3, vitaminA: 40, vitaminC: 3.9, waterPercentage: 68),
  SeedFood(name: 'Tuna (Canned in Water)', category: FoodCategory.fish, servingSize: '100g', servingGrams: 100, calories: 116, protein: 25, carbs: 0, fat: 1, fiber: 0, sugar: 0, sodium: 320, potassium: 240, calcium: 10, iron: 1.2, waterPercentage: 72),
  SeedFood(name: 'Tilapia', category: FoodCategory.fish, servingSize: '100g', servingGrams: 100, calories: 128, protein: 26, carbs: 0, fat: 3, fiber: 0, sugar: 0, sodium: 52, potassium: 300, calcium: 10, iron: 0.6, waterPercentage: 70),
  SeedFood(name: 'Hilsa (Cooked)', category: FoodCategory.fish, servingSize: '100g', servingGrams: 100, calories: 250, protein: 21, carbs: 0, fat: 18, fiber: 0, sugar: 0, sodium: 60, potassium: 300, calcium: 120, iron: 1.3, waterPercentage: 62),
  SeedFood(name: 'Rohu Fish (Cooked)', category: FoodCategory.fish, servingSize: '100g', servingGrams: 100, calories: 130, protein: 19, carbs: 0, fat: 6, fiber: 0, sugar: 0, sodium: 55, potassium: 280, calcium: 60, iron: 0.8, waterPercentage: 70),
  SeedFood(name: 'Catla Fish (Cooked)', category: FoodCategory.fish, servingSize: '100g', servingGrams: 100, calories: 140, protein: 18, carbs: 0, fat: 7, fiber: 0, sugar: 0, sodium: 55, potassium: 270, calcium: 55, iron: 0.7, waterPercentage: 70),
  SeedFood(name: 'Mackerel', category: FoodCategory.fish, servingSize: '100g', servingGrams: 100, calories: 205, protein: 19, carbs: 0, fat: 14, fiber: 0, sugar: 0, sodium: 70, potassium: 280, calcium: 12, iron: 1.6, waterPercentage: 66),
  SeedFood(name: 'Sardines', category: FoodCategory.fish, servingSize: '100g', servingGrams: 100, calories: 208, protein: 25, carbs: 0, fat: 11, fiber: 0, sugar: 0, sodium: 300, potassium: 400, calcium: 380, iron: 2.5, vitaminA: 32, waterPercentage: 64),
  SeedFood(name: 'Cod', category: FoodCategory.fish, servingSize: '100g', servingGrams: 100, calories: 82, protein: 18, carbs: 0, fat: 0.7, fiber: 0, sugar: 0, sodium: 54, potassium: 340, calcium: 16, iron: 0.4, waterPercentage: 78),
  SeedFood(name: 'Trout', category: FoodCategory.fish, servingSize: '100g', servingGrams: 100, calories: 149, protein: 21, carbs: 0, fat: 7, fiber: 0, sugar: 0, sodium: 51, potassium: 360, calcium: 18, iron: 0.3, waterPercentage: 73),
  SeedFood(name: 'Pomfret (Cooked)', category: FoodCategory.fish, servingSize: '100g', servingGrams: 100, calories: 175, protein: 19, carbs: 0, fat: 11, fiber: 0, sugar: 0, sodium: 60, potassium: 300, calcium: 40, iron: 0.8, waterPercentage: 65),
  SeedFood(name: 'Prawns (Shrimp)', category: FoodCategory.fish, servingSize: '100g', servingGrams: 100, calories: 99, protein: 24, carbs: 0.2, fat: 0.3, fiber: 0, sugar: 0, sodium: 111, potassium: 259, calcium: 70, iron: 0.5, waterPercentage: 75),
  SeedFood(name: 'Crab', category: FoodCategory.fish, servingSize: '100g', servingGrams: 100, calories: 97, protein: 19, carbs: 0, fat: 1.5, fiber: 0, sugar: 0, sodium: 380, potassium: 260, calcium: 90, iron: 0.7, waterPercentage: 78),
  SeedFood(name: 'Squid (Calamari)', category: FoodCategory.fish, servingSize: '100g', servingGrams: 100, calories: 92, protein: 16, carbs: 3, fat: 1.4, fiber: 0, sugar: 0, sodium: 45, potassium: 250, calcium: 30, iron: 0.7, waterPercentage: 78),

  // Egg
  SeedFood(name: 'Whole Egg (Boiled)', category: FoodCategory.egg, servingSize: '1 egg (50g)', servingGrams: 50, calories: 78, protein: 6.3, carbs: 0.6, fat: 5.3, fiber: 0, sugar: 0.6, sodium: 62, potassium: 63, calcium: 25, iron: 0.6, vitaminA: 80, vitaminC: 0, waterPercentage: 75),
  SeedFood(name: 'Egg White', category: FoodCategory.egg, servingSize: '1 egg (33g)', servingGrams: 33, calories: 17, protein: 3.6, carbs: 0.2, fat: 0, fiber: 0, sugar: 0.2, sodium: 55, potassium: 54, calcium: 2, iron: 0, waterPercentage: 88),
  SeedFood(name: 'Egg Yolk', category: FoodCategory.egg, servingSize: '1 yolk (17g)', servingGrams: 17, calories: 55, protein: 2.7, carbs: 0.6, fat: 4.5, fiber: 0, sugar: 0, sodium: 8, potassium: 19, calcium: 22, iron: 0.5, vitaminA: 109, waterPercentage: 52),
  SeedFood(name: 'Fried Egg', category: FoodCategory.egg, servingSize: '1 egg (50g)', servingGrams: 50, calories: 92, protein: 6.3, carbs: 0.4, fat: 7, fiber: 0, sugar: 0.4, sodium: 95, potassium: 68, calcium: 25, iron: 0.7, vitaminA: 90, waterPercentage: 72),
  SeedFood(name: 'Omelette', category: FoodCategory.egg, servingSize: '1 (60g)', servingGrams: 60, calories: 110, protein: 7, carbs: 1, fat: 8.5, fiber: 0.2, sugar: 0.8, sodium: 180, potassium: 80, calcium: 35, iron: 0.8, vitaminA: 110, waterPercentage: 70),
  SeedFood(name: 'Scrambled Eggs', category: FoodCategory.egg, servingSize: '2 eggs (100g)', servingGrams: 100, calories: 180, protein: 12, carbs: 2, fat: 14, fiber: 0, sugar: 2, sodium: 300, potassium: 140, calcium: 50, iron: 1.3, vitaminA: 180, waterPercentage: 68),
  SeedFood(name: 'Boiled Egg (2)', category: FoodCategory.egg, servingSize: '2 eggs (100g)', servingGrams: 100, calories: 155, protein: 12.6, carbs: 1.1, fat: 10.6, fiber: 0, sugar: 1.1, sodium: 124, potassium: 126, calcium: 50, iron: 1.2, vitaminA: 160, waterPercentage: 75),

  // Vegetables
  SeedFood(name: 'Broccoli (Steamed)', category: FoodCategory.vegetables, servingSize: '1 cup (90g)', servingGrams: 90, calories: 31, protein: 2.5, carbs: 6, fat: 0.4, fiber: 2.4, sugar: 1.5, sodium: 30, potassium: 290, calcium: 43, iron: 0.7, vitaminA: 42, vitaminC: 81, waterPercentage: 89),
  SeedFood(name: 'Spinach (Cooked)', category: FoodCategory.vegetables, servingSize: '1 cup (180g)', servingGrams: 180, calories: 41, protein: 5.3, carbs: 6.8, fat: 0.5, fiber: 4.3, sugar: 0.8, sodium: 126, potassium: 839, calcium: 245, iron: 6.4, vitaminA: 1410, vitaminC: 17, waterPercentage: 91),
  SeedFood(name: 'Carrot (Raw)', category: FoodCategory.vegetables, servingSize: '1 medium (61g)', servingGrams: 61, calories: 25, protein: 0.6, carbs: 6, fat: 0.1, fiber: 1.7, sugar: 2.9, sodium: 42, potassium: 195, calcium: 20, iron: 0.2, vitaminA: 509, vitaminC: 3.6, waterPercentage: 88),
  SeedFood(name: 'Tomato', category: FoodCategory.vegetables, servingSize: '1 medium (123g)', servingGrams: 123, calories: 22, protein: 1.1, carbs: 4.8, fat: 0.2, fiber: 1.5, sugar: 3.2, sodium: 6, potassium: 292, calcium: 12, iron: 0.3, vitaminA: 50, vitaminC: 16, waterPercentage: 94),
  SeedFood(name: 'Potato (Boiled)', category: FoodCategory.vegetables, servingSize: '1 medium (150g)', servingGrams: 150, calories: 129, protein: 2.9, carbs: 30, fat: 0.2, fiber: 3, sugar: 1.5, sodium: 8, potassium: 506, calcium: 12, iron: 0.5, vitaminC: 21, waterPercentage: 77),
  SeedFood(name: 'Sweet Potato (Baked)', category: FoodCategory.vegetables, servingSize: '1 medium (114g)', servingGrams: 114, calories: 103, protein: 2.3, carbs: 24, fat: 0.2, fiber: 3.8, sugar: 7.4, sodium: 41, potassium: 475, calcium: 43, iron: 0.7, vitaminA: 1094, vitaminC: 22, waterPercentage: 77),
  SeedFood(name: 'Cauliflower (Cooked)', category: FoodCategory.vegetables, servingSize: '1 cup (120g)', servingGrams: 120, calories: 27, protein: 2, carbs: 5, fat: 0.5, fiber: 2, sugar: 2, sodium: 20, potassium: 175, calcium: 20, iron: 0.5, vitaminC: 55, waterPercentage: 92),
  SeedFood(name: 'Cabbage (Shredded)', category: FoodCategory.vegetables, servingSize: '1 cup (90g)', servingGrams: 90, calories: 22, protein: 1.1, carbs: 5, fat: 0.1, fiber: 2.2, sugar: 2.8, sodium: 16, potassium: 151, calcium: 36, iron: 0.4, vitaminC: 33, waterPercentage: 92),
  SeedFood(name: 'Capsicum (Bell Pepper)', category: FoodCategory.vegetables, servingSize: '1 medium (119g)', servingGrams: 119, calories: 24, protein: 1, carbs: 6, fat: 0.2, fiber: 2.1, sugar: 3, sodium: 4, potassium: 208, calcium: 9, iron: 0.5, vitaminA: 69, vitaminC: 95, waterPercentage: 94),
  SeedFood(name: 'Cucumber', category: FoodCategory.vegetables, servingSize: '1 cup (104g)', servingGrams: 104, calories: 16, protein: 0.7, carbs: 3.8, fat: 0.1, fiber: 0.5, sugar: 1.7, sodium: 2, potassium: 147, calcium: 16, iron: 0.3, vitaminC: 2.8, waterPercentage: 95),
  SeedFood(name: 'Onion (Raw)', category: FoodCategory.vegetables, servingSize: '1 medium (110g)', servingGrams: 110, calories: 44, protein: 1.2, carbs: 10, fat: 0.1, fiber: 1.9, sugar: 4.7, sodium: 4, potassium: 161, calcium: 25, iron: 0.2, vitaminC: 8, waterPercentage: 89),
  SeedFood(name: 'Garlic', category: FoodCategory.vegetables, servingSize: '3 cloves (9g)', servingGrams: 9, calories: 13, protein: 0.6, carbs: 3, fat: 0, fiber: 0.2, sugar: 0.1, sodium: 1, potassium: 36, calcium: 16, iron: 0.2, vitaminC: 2.7, waterPercentage: 59),
  SeedFood(name: 'Green Beans (Cooked)', category: FoodCategory.vegetables, servingSize: '1 cup (125g)', servingGrams: 125, calories: 44, protein: 2.4, carbs: 10, fat: 0.3, fiber: 4, sugar: 4.6, sodium: 7, potassium: 183, calcium: 33, iron: 1.1, vitaminC: 12, waterPercentage: 90),
  SeedFood(name: 'Green Peas (Cooked)', category: FoodCategory.vegetables, servingSize: '1 cup (160g)', servingGrams: 160, calories: 134, protein: 8.6, carbs: 25, fat: 0.4, fiber: 8.8, sugar: 9.4, sodium: 4, potassium: 340, calcium: 40, iron: 2.5, vitaminC: 28, waterPercentage: 78),
  SeedFood(name: 'Mushroom (Cooked)', category: FoodCategory.vegetables, servingSize: '1 cup (90g)', servingGrams: 90, calories: 26, protein: 2, carbs: 5, fat: 0.4, fiber: 2, sugar: 2, sodium: 5, potassium: 296, calcium: 3, iron: 0.8, waterPercentage: 91),
  SeedFood(name: 'Pumpkin (Cooked)', category: FoodCategory.vegetables, servingSize: '1 cup (245g)', servingGrams: 245, calories: 49, protein: 2, carbs: 12, fat: 0.2, fiber: 3, sugar: 5, sodium: 2, potassium: 564, calcium: 37, iron: 1.4, vitaminA: 882, vitaminC: 12, waterPercentage: 94),
  SeedFood(name: 'Corn (Sweet, Cooked)', category: FoodCategory.vegetables, servingSize: '1 ear (90g)', servingGrams: 90, calories: 90, protein: 3, carbs: 19, fat: 1.3, fiber: 2.3, sugar: 3.2, sodium: 12, potassium: 240, calcium: 4, iron: 0.5, vitaminC: 6, waterPercentage: 70),
  SeedFood(name: 'Eggplant (Cooked)', category: FoodCategory.vegetables, servingSize: '1 cup (99g)', servingGrams: 99, calories: 35, protein: 0.8, carbs: 9, fat: 0.2, fiber: 2.5, sugar: 3, sodium: 2, potassium: 188, calcium: 6, iron: 0.3, waterPercentage: 90),
  SeedFood(name: 'Zucchini (Cooked)', category: FoodCategory.vegetables, servingSize: '1 cup (180g)', servingGrams: 180, calories: 27, protein: 1.4, carbs: 6, fat: 0.4, fiber: 2, sugar: 3, sodium: 9, potassium: 380, calcium: 30, iron: 0.7, vitaminC: 18, waterPercentage: 94),

  // Fruits
  SeedFood(name: 'Apple', category: FoodCategory.fruits, servingSize: '1 medium (182g)', servingGrams: 182, calories: 95, protein: 0.5, carbs: 25, fat: 0.3, fiber: 4.4, sugar: 19, sodium: 2, potassium: 195, calcium: 11, iron: 0.2, vitaminC: 8.4, waterPercentage: 86),
  SeedFood(name: 'Banana', category: FoodCategory.fruits, servingSize: '1 medium (118g)', servingGrams: 118, calories: 105, protein: 1.3, carbs: 27, fat: 0.4, fiber: 3.1, sugar: 14, sodium: 1, potassium: 422, calcium: 6, iron: 0.3, vitaminC: 10, waterPercentage: 75),
  SeedFood(name: 'Orange', category: FoodCategory.fruits, servingSize: '1 medium (131g)', servingGrams: 131, calories: 62, protein: 1.2, carbs: 15, fat: 0.2, fiber: 3.1, sugar: 12, sodium: 0, potassium: 237, calcium: 52, iron: 0.1, vitaminC: 70, waterPercentage: 87),
  SeedFood(name: 'Mango', category: FoodCategory.fruits, servingSize: '1 cup (165g)', servingGrams: 165, calories: 99, protein: 1.4, carbs: 25, fat: 0.6, fiber: 2.6, sugar: 23, sodium: 2, potassium: 277, calcium: 18, iron: 0.3, vitaminA: 178, vitaminC: 60, waterPercentage: 83),
  SeedFood(name: 'Grapes', category: FoodCategory.fruits, servingSize: '1 cup (151g)', servingGrams: 151, calories: 104, protein: 1.1, carbs: 27, fat: 0.2, fiber: 1.4, sugar: 23, sodium: 3, potassium: 288, calcium: 15, iron: 0.5, vitaminC: 5, waterPercentage: 81),
  SeedFood(name: 'Watermelon', category: FoodCategory.fruits, servingSize: '1 cup (152g)', servingGrams: 152, calories: 46, protein: 0.9, carbs: 12, fat: 0.2, fiber: 0.6, sugar: 9, sodium: 1, potassium: 170, calcium: 11, iron: 0.4, vitaminA: 43, vitaminC: 12, waterPercentage: 92),
  SeedFood(name: 'Papaya', category: FoodCategory.fruits, servingSize: '1 cup (145g)', servingGrams: 145, calories: 62, protein: 0.7, carbs: 16, fat: 0.4, fiber: 2.5, sugar: 11, sodium: 9, potassium: 263, calcium: 31, iron: 0.4, vitaminA: 68, vitaminC: 87, waterPercentage: 88),
  SeedFood(name: 'Guava', category: FoodCategory.fruits, servingSize: '1 fruit (100g)', servingGrams: 100, calories: 68, protein: 2.6, carbs: 14, fat: 0.9, fiber: 5.4, sugar: 9, sodium: 2, potassium: 417, calcium: 18, iron: 0.3, vitaminC: 228, waterPercentage: 81),
  SeedFood(name: 'Pineapple', category: FoodCategory.fruits, servingSize: '1 cup (165g)', servingGrams: 165, calories: 82, protein: 0.9, carbs: 22, fat: 0.2, fiber: 2.3, sugar: 16, sodium: 2, potassium: 180, calcium: 21, iron: 0.5, vitaminC: 79, waterPercentage: 86),
  SeedFood(name: 'Strawberries', category: FoodCategory.fruits, servingSize: '1 cup (152g)', servingGrams: 152, calories: 49, protein: 1, carbs: 12, fat: 0.5, fiber: 3, sugar: 7.4, sodium: 1, potassium: 233, calcium: 24, iron: 0.6, vitaminC: 89, waterPercentage: 91),
  SeedFood(name: 'Blueberries', category: FoodCategory.fruits, servingSize: '1 cup (148g)', servingGrams: 148, calories: 84, protein: 1.1, carbs: 21, fat: 0.5, fiber: 3.6, sugar: 15, sodium: 1, potassium: 114, calcium: 9, iron: 0.4, vitaminC: 14, waterPercentage: 84),
  SeedFood(name: 'Litchi', category: FoodCategory.fruits, servingSize: '1 cup (190g)', servingGrams: 190, calories: 125, protein: 1.6, carbs: 31, fat: 0.8, fiber: 2.5, sugar: 29, sodium: 1, potassium: 325, calcium: 10, iron: 0.6, vitaminC: 136, waterPercentage: 82),
  SeedFood(name: 'Jackfruit', category: FoodCategory.fruits, servingSize: '1 cup (165g)', servingGrams: 165, calories: 155, protein: 2.4, carbs: 38, fat: 1.1, fiber: 2.5, sugar: 32, sodium: 3, potassium: 739, calcium: 34, iron: 0.4, vitaminC: 22, waterPercentage: 73),
  SeedFood(name: 'Pomegranate', category: FoodCategory.fruits, servingSize: '1/2 fruit (87g)', servingGrams: 87, calories: 72, protein: 1.5, carbs: 16, fat: 1, fiber: 3.5, sugar: 12, sodium: 2, potassium: 205, calcium: 9, iron: 0.3, vitaminC: 9, waterPercentage: 81),
  SeedFood(name: 'Kiwi', category: FoodCategory.fruits, servingSize: '1 fruit (69g)', servingGrams: 69, calories: 42, protein: 0.8, carbs: 10, fat: 0.4, fiber: 2.1, sugar: 6, sodium: 2, potassium: 215, calcium: 23, iron: 0.2, vitaminC: 64, waterPercentage: 83),
  SeedFood(name: 'Pear', category: FoodCategory.fruits, servingSize: '1 medium (178g)', servingGrams: 178, calories: 101, protein: 0.6, carbs: 27, fat: 0.2, fiber: 5.5, sugar: 17, sodium: 1, potassium: 206, calcium: 16, iron: 0.2, vitaminC: 7, waterPercentage: 84),
  SeedFood(name: 'Peach', category: FoodCategory.fruits, servingSize: '1 medium (150g)', servingGrams: 150, calories: 59, protein: 1.4, carbs: 14, fat: 0.4, fiber: 2.3, sugar: 12, sodium: 0, potassium: 285, calcium: 10, iron: 0.4, vitaminA: 24, vitaminC: 10, waterPercentage: 89),
  SeedFood(name: 'Lemon', category: FoodCategory.fruits, servingSize: '1 fruit (58g)', servingGrams: 58, calories: 17, protein: 0.6, carbs: 5, fat: 0.2, fiber: 1.6, sugar: 1.5, sodium: 1, potassium: 80, calcium: 15, iron: 0.4, vitaminC: 31, waterPercentage: 89),
  SeedFood(name: 'Dates', category: FoodCategory.fruits, servingSize: '3 dates (24g)', servingGrams: 24, calories: 66, protein: 0.5, carbs: 18, fat: 0, fiber: 1.9, sugar: 16, sodium: 0, potassium: 167, calcium: 16, iron: 0.2, waterPercentage: 20),
  SeedFood(name: 'Avocado', category: FoodCategory.fruits, servingSize: '1/2 fruit (100g)', servingGrams: 100, calories: 160, protein: 2, carbs: 8.5, fat: 14.7, fiber: 6.7, sugar: 0.7, sodium: 7, potassium: 485, calcium: 12, iron: 0.6, vitaminA: 7, vitaminC: 10, waterPercentage: 73),

  // Milk
  SeedFood(name: 'Whole Milk', category: FoodCategory.milk, servingSize: '1 cup (244g)', servingGrams: 244, calories: 149, protein: 7.7, carbs: 12, fat: 8, fiber: 0, sugar: 12, sodium: 105, potassium: 322, calcium: 276, iron: 0.1, vitaminA: 56, vitaminC: 0, waterPercentage: 87),
  SeedFood(name: 'Low Fat Milk (2%)', category: FoodCategory.milk, servingSize: '1 cup (244g)', servingGrams: 244, calories: 122, protein: 8.1, carbs: 12, fat: 4.8, fiber: 0, sugar: 12, sodium: 107, potassium: 366, calcium: 293, iron: 0.1, vitaminA: 64, vitaminC: 0, waterPercentage: 89),
  SeedFood(name: 'Skim Milk', category: FoodCategory.milk, servingSize: '1 cup (245g)', servingGrams: 245, calories: 83, protein: 8.3, carbs: 12, fat: 0.2, fiber: 0, sugar: 12, sodium: 103, potassium: 382, calcium: 299, iron: 0.1, vitaminA: 62, waterPercentage: 91),
  SeedFood(name: 'Soy Milk', category: FoodCategory.milk, servingSize: '1 cup (243g)', servingGrams: 243, calories: 80, protein: 7, carbs: 4, fat: 4, fiber: 1, sugar: 1, sodium: 90, potassium: 300, calcium: 300, iron: 1, waterPercentage: 90),
  SeedFood(name: 'Almond Milk', category: FoodCategory.milk, servingSize: '1 cup (240g)', servingGrams: 240, calories: 39, protein: 1, carbs: 3.4, fat: 2.5, fiber: 0.5, sugar: 2, sodium: 189, potassium: 220, calcium: 482, iron: 0.7, waterPercentage: 93),
  SeedFood(name: 'Oat Milk', category: FoodCategory.milk, servingSize: '1 cup (240g)', servingGrams: 240, calories: 120, protein: 3, carbs: 16, fat: 5, fiber: 2, sugar: 7, sodium: 100, potassium: 180, calcium: 350, iron: 1, waterPercentage: 90),
  SeedFood(name: 'Condensed Milk', category: FoodCategory.milk, servingSize: '2 tbsp (38g)', servingGrams: 38, calories: 123, protein: 3.1, carbs: 21, fat: 3.3, fiber: 0, sugar: 21, sodium: 51, potassium: 127, calcium: 106, iron: 0.1, waterPercentage: 27),
  SeedFood(name: 'Buttermilk', category: FoodCategory.milk, servingSize: '1 cup (245g)', servingGrams: 245, calories: 98, protein: 8, carbs: 12, fat: 2.5, fiber: 0, sugar: 12, sodium: 257, potassium: 345, calcium: 282, iron: 0.1, vitaminA: 40, waterPercentage: 90),
  SeedFood(name: 'Lassi (Sweet)', category: FoodCategory.milk, servingSize: '1 cup (240g)', servingGrams: 240, calories: 160, protein: 6, carbs: 26, fat: 4, fiber: 0, sugar: 22, sodium: 80, potassium: 320, calcium: 240, iron: 0.1, waterPercentage: 85),

  // Dairy
  SeedFood(name: 'Greek Yogurt (Plain)', category: FoodCategory.dairy, servingSize: '1 cup (245g)', servingGrams: 245, calories: 130, protein: 22, carbs: 9, fat: 0.7, fiber: 0, sugar: 9, sodium: 65, potassium: 240, calcium: 250, iron: 0, waterPercentage: 82),
  SeedFood(name: 'Plain Yogurt (Full Fat)', category: FoodCategory.dairy, servingSize: '1 cup (245g)', servingGrams: 245, calories: 149, protein: 8.5, carbs: 11, fat: 8, fiber: 0, sugar: 11, sodium: 113, potassium: 380, calcium: 296, iron: 0.1, vitaminA: 34, waterPercentage: 88),
  SeedFood(name: 'Cheddar Cheese', category: FoodCategory.dairy, servingSize: '1 slice (28g)', servingGrams: 28, calories: 114, protein: 6.4, carbs: 0.4, fat: 9.4, fiber: 0, sugar: 0.1, sodium: 181, potassium: 28, calcium: 202, iron: 0.1, vitaminA: 70, waterPercentage: 37),
  SeedFood(name: 'Mozzarella Cheese', category: FoodCategory.dairy, servingSize: '1/4 cup (28g)', servingGrams: 28, calories: 85, protein: 6.3, carbs: 0.6, fat: 6.3, fiber: 0, sugar: 0.2, sodium: 178, potassium: 24, calcium: 143, iron: 0, waterPercentage: 50),
  SeedFood(name: 'Cottage Cheese', category: FoodCategory.dairy, servingSize: '1 cup (226g)', servingGrams: 226, calories: 163, protein: 28, carbs: 6, fat: 2.3, fiber: 0, sugar: 5, sodium: 706, potassium: 194, calcium: 227, iron: 0.2, waterPercentage: 79),
  SeedFood(name: 'Cream Cheese', category: FoodCategory.dairy, servingSize: '2 tbsp (29g)', servingGrams: 29, calories: 102, protein: 1.8, carbs: 1.5, fat: 10, fiber: 0, sugar: 1, sodium: 87, potassium: 34, calcium: 23, iron: 0, vitaminA: 91, waterPercentage: 53),
  SeedFood(name: 'Parmesan Cheese', category: FoodCategory.dairy, servingSize: '1 tbsp (10g)', servingGrams: 10, calories: 42, protein: 3.8, carbs: 0.3, fat: 2.8, fiber: 0, sugar: 0.1, sodium: 152, potassium: 9, calcium: 110, iron: 0, waterPercentage: 18),
  SeedFood(name: 'Butter', category: FoodCategory.dairy, servingSize: '1 tbsp (14g)', servingGrams: 14, calories: 102, protein: 0.1, carbs: 0, fat: 11.5, fiber: 0, sugar: 0, sodium: 91, potassium: 3, calcium: 3, iron: 0, vitaminA: 97, waterPercentage: 16),
  SeedFood(name: 'Heavy Cream', category: FoodCategory.dairy, servingSize: '2 tbsp (30g)', servingGrams: 30, calories: 103, protein: 0.6, carbs: 0.8, fat: 11, fiber: 0, sugar: 0.8, sodium: 11, potassium: 29, calcium: 23, iron: 0, vitaminA: 130, waterPercentage: 58),
  SeedFood(name: 'Ice Cream (Vanilla)', category: FoodCategory.dairy, servingSize: '1 scoop (66g)', servingGrams: 66, calories: 137, protein: 2.3, carbs: 16, fat: 7.3, fiber: 0.5, sugar: 14, sodium: 53, potassium: 132, calcium: 84, iron: 0.1, vitaminA: 90, waterPercentage: 61),

  // Fast Food
  SeedFood(name: 'Hamburger', category: FoodCategory.fastFood, servingSize: '1 burger (105g)', servingGrams: 105, calories: 250, protein: 13, carbs: 31, fat: 9, fiber: 1.5, sugar: 6, sodium: 480, potassium: 240, calcium: 60, iron: 2.4, waterPercentage: 55),
  SeedFood(name: 'Cheeseburger', category: FoodCategory.fastFood, servingSize: '1 burger (114g)', servingGrams: 114, calories: 303, protein: 15, carbs: 31, fat: 14, fiber: 1.5, sugar: 6, sodium: 510, potassium: 230, calcium: 90, iron: 2.5, waterPercentage: 53),
  SeedFood(name: 'Chicken Burger', category: FoodCategory.fastFood, servingSize: '1 burger (170g)', servingGrams: 170, calories: 460, protein: 22, carbs: 40, fat: 24, fiber: 2, sugar: 7, sodium: 800, potassium: 300, calcium: 80, iron: 1.8, waterPercentage: 50),
  SeedFood(name: 'French Fries', category: FoodCategory.fastFood, servingSize: 'medium (117g)', servingGrams: 117, calories: 365, protein: 4, carbs: 48, fat: 17, fiber: 4.3, sugar: 0.3, sodium: 246, potassium: 579, calcium: 12, iron: 1.5, vitaminC: 14, waterPercentage: 55),
  SeedFood(name: 'Pizza Slice (Cheese)', category: FoodCategory.fastFood, servingSize: '1 slice (107g)', servingGrams: 107, calories: 285, protein: 12, carbs: 36, fat: 10, fiber: 2.5, sugar: 3.8, sodium: 640, potassium: 190, calcium: 170, iron: 1.8, waterPercentage: 46),
  SeedFood(name: 'Hot Dog', category: FoodCategory.fastFood, servingSize: '1 (98g)', servingGrams: 98, calories: 290, protein: 10, carbs: 24, fat: 17, fiber: 1, sugar: 5, sodium: 720, potassium: 150, calcium: 30, iron: 1.2, waterPercentage: 55),
  SeedFood(name: 'Shawarma Wrap', category: FoodCategory.fastFood, servingSize: '1 wrap (280g)', servingGrams: 280, calories: 620, protein: 30, carbs: 55, fat: 30, fiber: 4, sugar: 5, sodium: 900, potassium: 400, calcium: 120, iron: 3, waterPercentage: 50),
  SeedFood(name: 'Fried Fish Fillet', category: FoodCategory.fastFood, servingSize: '1 fillet (85g)', servingGrams: 85, calories: 240, protein: 15, carbs: 15, fat: 13, fiber: 1, sugar: 1, sodium: 400, potassium: 260, calcium: 20, iron: 0.8, waterPercentage: 55),
  SeedFood(name: 'Samosa', category: FoodCategory.fastFood, servingSize: '1 piece (75g)', servingGrams: 75, calories: 190, protein: 4, carbs: 22, fat: 10, fiber: 1.5, sugar: 1, sodium: 280, potassium: 150, calcium: 12, iron: 0.9, waterPercentage: 40),
  SeedFood(name: 'Spring Roll', category: FoodCategory.fastFood, servingSize: '1 piece (50g)', servingGrams: 50, calories: 120, protein: 3, carbs: 12, fat: 7, fiber: 1, sugar: 1, sodium: 250, potassium: 80, calcium: 10, iron: 0.5, waterPercentage: 45),
  SeedFood(name: 'Chicken Nuggets', category: FoodCategory.fastFood, servingSize: '6 pieces (96g)', servingGrams: 96, calories: 280, protein: 14, carbs: 17, fat: 18, fiber: 1, sugar: 1, sodium: 600, potassium: 230, calcium: 20, iron: 1, waterPercentage: 50),
  SeedFood(name: 'Nachos with Cheese', category: FoodCategory.fastFood, servingSize: '1 plate (150g)', servingGrams: 150, calories: 450, protein: 12, carbs: 48, fat: 24, fiber: 5, sugar: 3, sodium: 700, potassium: 300, calcium: 200, iron: 1.5, waterPercentage: 45),
  SeedFood(name: 'Pasta Carbonara', category: FoodCategory.fastFood, servingSize: '1 bowl (250g)', servingGrams: 250, calories: 520, protein: 18, carbs: 55, fat: 25, fiber: 3, sugar: 3, sodium: 800, potassium: 250, calcium: 100, iron: 2, waterPercentage: 62),
  SeedFood(name: 'Chicken Chowmein', category: FoodCategory.fastFood, servingSize: '1 bowl (300g)', servingGrams: 300, calories: 480, protein: 22, carbs: 60, fat: 18, fiber: 4, sugar: 6, sodium: 950, potassium: 350, calcium: 50, iron: 2.5, waterPercentage: 60),

  // Dessert
  SeedFood(name: 'Chocolate Cake', category: FoodCategory.dessert, servingSize: '1 slice (100g)', servingGrams: 100, calories: 370, protein: 4.5, carbs: 52, fat: 16, fiber: 2, sugar: 38, sodium: 280, potassium: 150, calcium: 60, iron: 1.5, waterPercentage: 27),
  SeedFood(name: 'Vanilla Cake', category: FoodCategory.dessert, servingSize: '1 slice (90g)', servingGrams: 90, calories: 320, protein: 3.5, carbs: 48, fat: 13, fiber: 0.5, sugar: 32, sodium: 250, potassium: 100, calcium: 70, iron: 0.8, waterPercentage: 26),
  SeedFood(name: 'Glazed Donut', category: FoodCategory.dessert, servingSize: '1 (60g)', servingGrams: 60, calories: 240, protein: 3, carbs: 28, fat: 13, fiber: 0.8, sugar: 15, sodium: 210, potassium: 70, calcium: 15, iron: 1, waterPercentage: 22),
  SeedFood(name: 'Chocolate Brownie', category: FoodCategory.dessert, servingSize: '1 (50g)', servingGrams: 50, calories: 220, protein: 2.5, carbs: 28, fat: 12, fiber: 1.5, sugar: 20, sodium: 150, potassium: 90, calcium: 25, iron: 1.2, waterPercentage: 18),
  SeedFood(name: 'Chocolate Chip Cookie', category: FoodCategory.dessert, servingSize: '1 (20g)', servingGrams: 20, calories: 95, protein: 1, carbs: 12, fat: 5, fiber: 0.5, sugar: 7, sodium: 80, potassium: 35, calcium: 8, iron: 0.4, waterPercentage: 5),
  SeedFood(name: 'Blueberry Muffin', category: FoodCategory.dessert, servingSize: '1 (110g)', servingGrams: 110, calories: 350, protein: 5, carbs: 50, fat: 15, fiber: 1.5, sugar: 25, sodium: 300, potassium: 120, calcium: 60, iron: 1.2, waterPercentage: 30),
  SeedFood(name: 'Pancakes', category: FoodCategory.dessert, servingSize: '2 (110g)', servingGrams: 110, calories: 260, protein: 7, carbs: 40, fat: 8, fiber: 1.5, sugar: 12, sodium: 480, potassium: 150, calcium: 90, iron: 1.5, waterPercentage: 45),
  SeedFood(name: 'Waffle', category: FoodCategory.dessert, servingSize: '1 (80g)', servingGrams: 80, calories: 240, protein: 6, carbs: 30, fat: 11, fiber: 1, sugar: 8, sodium: 420, potassium: 120, calcium: 100, iron: 1.4, waterPercentage: 40),
  SeedFood(name: 'Custard', category: FoodCategory.dessert, servingSize: '1 cup (245g)', servingGrams: 245, calories: 190, protein: 6, carbs: 28, fat: 6, fiber: 0, sugar: 24, sodium: 120, potassium: 250, calcium: 200, iron: 0.2, waterPercentage: 74),
  SeedFood(name: 'Rice Pudding (Kheer)', category: FoodCategory.dessert, servingSize: '1 bowl (200g)', servingGrams: 200, calories: 220, protein: 5, carbs: 35, fat: 7, fiber: 0.5, sugar: 22, sodium: 90, potassium: 150, calcium: 120, iron: 0.5, waterPercentage: 70),
  SeedFood(name: 'Jalebi', category: FoodCategory.dessert, servingSize: '1 piece (60g)', servingGrams: 60, calories: 240, protein: 2, carbs: 40, fat: 9, fiber: 0.5, sugar: 35, sodium: 10, potassium: 60, calcium: 10, iron: 0.8, waterPercentage: 15),
  SeedFood(name: 'Gulab Jamun', category: FoodCategory.dessert, servingSize: '2 pieces (80g)', servingGrams: 80, calories: 270, protein: 3, carbs: 40, fat: 12, fiber: 0.5, sugar: 32, sodium: 80, potassium: 90, calcium: 50, iron: 0.6, waterPercentage: 25),
  SeedFood(name: 'Rasgulla', category: FoodCategory.dessert, servingSize: '2 pieces (90g)', servingGrams: 90, calories: 180, protein: 4, carbs: 36, fat: 2, fiber: 0, sugar: 30, sodium: 50, potassium: 80, calcium: 90, iron: 0.2, waterPercentage: 62),
  SeedFood(name: 'Dark Chocolate', category: FoodCategory.dessert, servingSize: '2 squares (30g)', servingGrams: 30, calories: 170, protein: 2.3, carbs: 13, fat: 12, fiber: 3.4, sugar: 7, sodium: 7, potassium: 170, calcium: 13, iron: 3.4, waterPercentage: 1),

  // Drinks
  SeedFood(name: 'Water', category: FoodCategory.drinks, servingSize: '1 glass (250ml)', servingGrams: 250, calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0, sugar: 0, sodium: 2, potassium: 0, calcium: 7, iron: 0, waterPercentage: 100),
  SeedFood(name: 'Orange Juice', category: FoodCategory.drinks, servingSize: '1 cup (248g)', servingGrams: 248, calories: 112, protein: 1.7, carbs: 26, fat: 0.5, fiber: 0.5, sugar: 21, sodium: 2, potassium: 496, calcium: 27, iron: 0.5, vitaminC: 124, waterPercentage: 88),
  SeedFood(name: 'Apple Juice', category: FoodCategory.drinks, servingSize: '1 cup (248g)', servingGrams: 248, calories: 114, protein: 0.2, carbs: 28, fat: 0.3, fiber: 0.5, sugar: 24, sodium: 10, potassium: 250, calcium: 20, iron: 0.6, vitaminC: 2, waterPercentage: 88),
  SeedFood(name: 'Mango Juice', category: FoodCategory.drinks, servingSize: '1 cup (250g)', servingGrams: 250, calories: 130, protein: 0.5, carbs: 32, fat: 0.3, fiber: 0.5, sugar: 28, sodium: 8, potassium: 140, calcium: 15, iron: 0.3, vitaminC: 30, waterPercentage: 87),
  SeedFood(name: 'Lemonade', category: FoodCategory.drinks, servingSize: '1 cup (240g)', servingGrams: 240, calories: 99, protein: 0, carbs: 26, fat: 0, fiber: 0, sugar: 25, sodium: 10, potassium: 15, calcium: 3, iron: 0.1, vitaminC: 10, waterPercentage: 89),
  SeedFood(name: 'Iced Tea', category: FoodCategory.drinks, servingSize: '1 cup (240g)', servingGrams: 240, calories: 90, protein: 0, carbs: 23, fat: 0, fiber: 0, sugar: 22, sodium: 8, potassium: 12, calcium: 2, iron: 0.1, waterPercentage: 90),
  SeedFood(name: 'Green Tea', category: FoodCategory.drinks, servingSize: '1 cup (240g)', servingGrams: 240, calories: 2, protein: 0, carbs: 0.4, fat: 0, fiber: 0, sugar: 0, sodium: 5, potassium: 20, calcium: 2, iron: 0, waterPercentage: 99),
  SeedFood(name: 'Black Coffee', category: FoodCategory.drinks, servingSize: '1 cup (240g)', servingGrams: 240, calories: 2, protein: 0.3, carbs: 0, fat: 0, fiber: 0, sugar: 0, sodium: 5, potassium: 116, calcium: 5, iron: 0, waterPercentage: 99),
  SeedFood(name: 'Latte', category: FoodCategory.drinks, servingSize: '1 cup (300g)', servingGrams: 300, calories: 150, protein: 8, carbs: 15, fat: 6, fiber: 0, sugar: 14, sodium: 140, potassium: 400, calcium: 250, iron: 0.2, waterPercentage: 90),
  SeedFood(name: 'Cappuccino', category: FoodCategory.drinks, servingSize: '1 cup (240g)', servingGrams: 240, calories: 80, protein: 4, carbs: 8, fat: 3.5, fiber: 0, sugar: 7, sodium: 80, potassium: 200, calcium: 130, iron: 0.1, waterPercentage: 92),
  SeedFood(name: 'Cola', category: FoodCategory.drinks, servingSize: '1 can (330ml)', servingGrams: 330, calories: 139, protein: 0, carbs: 39, fat: 0, fiber: 0, sugar: 39, sodium: 14, potassium: 3, calcium: 0, iron: 0, waterPercentage: 89),
  SeedFood(name: 'Diet Cola', category: FoodCategory.drinks, servingSize: '1 can (330ml)', servingGrams: 330, calories: 1, protein: 0, carbs: 0.2, fat: 0, fiber: 0, sugar: 0, sodium: 20, potassium: 4, calcium: 0, iron: 0, waterPercentage: 99),
  SeedFood(name: 'Energy Drink', category: FoodCategory.drinks, servingSize: '1 can (250ml)', servingGrams: 250, calories: 110, protein: 0, carbs: 28, fat: 0, fiber: 0, sugar: 27, sodium: 50, potassium: 20, calcium: 2, iron: 0.1, waterPercentage: 89),
  SeedFood(name: 'Coconut Water', category: FoodCategory.drinks, servingSize: '1 cup (240g)', servingGrams: 240, calories: 46, protein: 1.7, carbs: 9, fat: 0.5, fiber: 2.6, sugar: 6, sodium: 252, potassium: 600, calcium: 58, iron: 0.7, vitaminC: 5, waterPercentage: 95),
  SeedFood(name: 'Milkshake', category: FoodCategory.drinks, servingSize: '1 cup (240g)', servingGrams: 240, calories: 240, protein: 8, carbs: 32, fat: 9, fiber: 0.5, sugar: 28, sodium: 160, potassium: 380, calcium: 300, iron: 0.2, waterPercentage: 75),
  SeedFood(name: 'Fruit Smoothie', category: FoodCategory.drinks, servingSize: '1 cup (240g)', servingGrams: 240, calories: 150, protein: 3, carbs: 30, fat: 2, fiber: 3, sugar: 22, sodium: 20, potassium: 350, calcium: 60, iron: 0.5, vitaminC: 40, waterPercentage: 85),

  // Nuts
  SeedFood(name: 'Almonds', category: FoodCategory.nuts, servingSize: '1/4 cup (28g)', servingGrams: 28, calories: 164, protein: 6, carbs: 6, fat: 14, fiber: 3.5, sugar: 1.2, sodium: 0, potassium: 200, calcium: 76, iron: 1, waterPercentage: 4),
  SeedFood(name: 'Cashews', category: FoodCategory.nuts, servingSize: '1/4 cup (28g)', servingGrams: 28, calories: 157, protein: 5, carbs: 9, fat: 12, fiber: 1, sugar: 1.7, sodium: 3, potassium: 160, calcium: 10, iron: 1.9, waterPercentage: 5),
  SeedFood(name: 'Peanuts', category: FoodCategory.nuts, servingSize: '1/4 cup (36g)', servingGrams: 36, calories: 207, protein: 9.4, carbs: 6, fat: 18, fiber: 3, sugar: 2, sodium: 5, potassium: 220, calcium: 32, iron: 1.3, waterPercentage: 5),
  SeedFood(name: 'Walnuts', category: FoodCategory.nuts, servingSize: '1/4 cup (28g)', servingGrams: 28, calories: 185, protein: 4.3, carbs: 4, fat: 18, fiber: 1.9, sugar: 0.7, sodium: 1, potassium: 125, calcium: 28, iron: 0.8, waterPercentage: 4),
  SeedFood(name: 'Pistachios', category: FoodCategory.nuts, servingSize: '1/4 cup (30g)', servingGrams: 30, calories: 160, protein: 6, carbs: 8, fat: 13, fiber: 3, sugar: 2, sodium: 0, potassium: 300, calcium: 30, iron: 1.2, waterPercentage: 4),
  SeedFood(name: 'Hazelnuts', category: FoodCategory.nuts, servingSize: '1/4 cup (28g)', servingGrams: 28, calories: 178, protein: 4.2, carbs: 4.7, fat: 17, fiber: 2.8, sugar: 1.2, sodium: 0, potassium: 193, calcium: 32, iron: 1.3, waterPercentage: 5),
  SeedFood(name: 'Macadamia Nuts', category: FoodCategory.nuts, servingSize: '1/4 cup (28g)', servingGrams: 28, calories: 204, protein: 2.2, carbs: 4, fat: 21, fiber: 2.4, sugar: 1.3, sodium: 1, potassium: 104, calcium: 24, iron: 1, waterPercentage: 2),
  SeedFood(name: 'Pecans', category: FoodCategory.nuts, servingSize: '1/4 cup (28g)', servingGrams: 28, calories: 196, protein: 2.6, carbs: 4, fat: 20, fiber: 2.7, sugar: 1.1, sodium: 0, potassium: 116, calcium: 20, iron: 0.7, waterPercentage: 4),
  SeedFood(name: 'Brazil Nuts', category: FoodCategory.nuts, servingSize: '1/4 cup (28g)', servingGrams: 28, calories: 185, protein: 4, carbs: 3.5, fat: 19, fiber: 2.1, sugar: 0.7, sodium: 1, potassium: 187, calcium: 45, iron: 0.7, waterPercentage: 3),
  SeedFood(name: 'Peanut Butter', category: FoodCategory.nuts, servingSize: '2 tbsp (32g)', servingGrams: 32, calories: 190, protein: 8, carbs: 7, fat: 16, fiber: 2, sugar: 3, sodium: 137, potassium: 190, calcium: 15, iron: 0.6, waterPercentage: 2),
  SeedFood(name: 'Almond Butter', category: FoodCategory.nuts, servingSize: '2 tbsp (32g)', servingGrams: 32, calories: 196, protein: 6, carbs: 6, fat: 18, fiber: 3.3, sugar: 1.5, sodium: 73, potassium: 240, calcium: 110, iron: 1.1, waterPercentage: 2),
  SeedFood(name: 'Mixed Nuts', category: FoodCategory.nuts, servingSize: '1/4 cup (30g)', servingGrams: 30, calories: 175, protein: 5, carbs: 7, fat: 15, fiber: 2.5, sugar: 1.5, sodium: 90, potassium: 180, calcium: 30, iron: 1.2, waterPercentage: 4),

  // Seeds
  SeedFood(name: 'Chia Seeds', category: FoodCategory.seeds, servingSize: '2 tbsp (28g)', servingGrams: 28, calories: 138, protein: 4.7, carbs: 12, fat: 8.7, fiber: 9.8, sugar: 0, sodium: 5, potassium: 115, calcium: 179, iron: 2.2, waterPercentage: 5),
  SeedFood(name: 'Flax Seeds', category: FoodCategory.seeds, servingSize: '2 tbsp (20g)', servingGrams: 20, calories: 110, protein: 3.8, carbs: 6, fat: 8.7, fiber: 5.4, sugar: 0.3, sodium: 6, potassium: 160, calcium: 50, iron: 1.2, waterPercentage: 4),
  SeedFood(name: 'Sunflower Seeds', category: FoodCategory.seeds, servingSize: '1/4 cup (32g)', servingGrams: 32, calories: 186, protein: 6.3, carbs: 6.5, fat: 16, fiber: 3, sugar: 0.8, sodium: 3, potassium: 240, calcium: 26, iron: 1.6, waterPercentage: 4),
  SeedFood(name: 'Pumpkin Seeds', category: FoodCategory.seeds, servingSize: '1/4 cup (30g)', servingGrams: 30, calories: 168, protein: 9, carbs: 3, fat: 15, fiber: 2, sugar: 0.4, sodium: 5, potassium: 260, calcium: 16, iron: 2.6, waterPercentage: 4),
  SeedFood(name: 'Sesame Seeds', category: FoodCategory.seeds, servingSize: '2 tbsp (18g)', servingGrams: 18, calories: 104, protein: 3.2, carbs: 4.2, fat: 9, fiber: 2.1, sugar: 0.1, sodium: 2, potassium: 84, calcium: 176, iron: 2.6, waterPercentage: 5),
  SeedFood(name: 'Poppy Seeds', category: FoodCategory.seeds, servingSize: '1 tbsp (9g)', servingGrams: 9, calories: 46, protein: 1.6, carbs: 2.5, fat: 3.7, fiber: 1.7, sugar: 0.3, sodium: 2, potassium: 63, calcium: 127, iron: 0.8, waterPercentage: 6),
  SeedFood(name: 'Hemp Seeds', category: FoodCategory.seeds, servingSize: '3 tbsp (30g)', servingGrams: 30, calories: 166, protein: 9.5, carbs: 2.6, fat: 15, fiber: 1.2, sugar: 0.5, sodium: 1, potassium: 360, calcium: 21, iron: 2.4, waterPercentage: 5),
  SeedFood(name: 'Quinoa (Cooked)', category: FoodCategory.seeds, servingSize: '1 cup (185g)', servingGrams: 185, calories: 222, protein: 8, carbs: 39, fat: 3.6, fiber: 5, sugar: 1.6, sodium: 13, potassium: 318, calcium: 31, iron: 2.8, waterPercentage: 72),
  SeedFood(name: 'Tahini', category: FoodCategory.seeds, servingSize: '2 tbsp (30g)', servingGrams: 30, calories: 178, protein: 5, carbs: 6, fat: 16, fiber: 2.8, sugar: 0.1, sodium: 33, potassium: 124, calcium: 154, iron: 3.1, waterPercentage: 3),
  SeedFood(name: 'Basil Seeds (Sabja)', category: FoodCategory.seeds, servingSize: '1 tbsp (10g)', servingGrams: 10, calories: 40, protein: 1.6, carbs: 6, fat: 1.3, fiber: 4, sugar: 0.1, sodium: 1, potassium: 45, calcium: 45, iron: 0.8, waterPercentage: 5),

  // Healthy Snacks
  SeedFood(name: 'Oats (Dry)', category: FoodCategory.healthySnacks, servingSize: '1/2 cup (40g)', servingGrams: 40, calories: 154, protein: 5.4, carbs: 27, fat: 2.7, fiber: 4, sugar: 1, sodium: 2, potassium: 150, calcium: 21, iron: 1.8, waterPercentage: 9),
  SeedFood(name: 'Granola', category: FoodCategory.healthySnacks, servingSize: '1/2 cup (50g)', servingGrams: 50, calories: 240, protein: 5, carbs: 30, fat: 12, fiber: 3.5, sugar: 12, sodium: 40, potassium: 150, calcium: 30, iron: 1.5, waterPercentage: 4),
  SeedFood(name: 'Muesli', category: FoodCategory.healthySnacks, servingSize: '1/2 cup (50g)', servingGrams: 50, calories: 190, protein: 5, carbs: 33, fat: 4, fiber: 4.5, sugar: 8, sodium: 20, potassium: 220, calcium: 40, iron: 1.8, waterPercentage: 8),
  SeedFood(name: 'Air-Popped Popcorn', category: FoodCategory.healthySnacks, servingSize: '3 cups (24g)', servingGrams: 24, calories: 93, protein: 3, carbs: 18.6, fat: 1, fiber: 3.5, sugar: 0.2, sodium: 2, potassium: 70, calcium: 2, iron: 0.7, waterPercentage: 8),
  SeedFood(name: 'Protein Bar', category: FoodCategory.healthySnacks, servingSize: '1 bar (60g)', servingGrams: 60, calories: 210, protein: 20, carbs: 22, fat: 7, fiber: 2, sugar: 9, sodium: 200, potassium: 150, calcium: 100, iron: 1.5, waterPercentage: 8),
  SeedFood(name: 'Granola Bar', category: FoodCategory.healthySnacks, servingSize: '1 bar (25g)', servingGrams: 25, calories: 110, protein: 2, carbs: 17, fat: 4, fiber: 1.2, sugar: 8, sodium: 60, potassium: 70, calcium: 10, iron: 0.5, waterPercentage: 6),
  SeedFood(name: 'Hummus', category: FoodCategory.healthySnacks, servingSize: '2 tbsp (30g)', servingGrams: 30, calories: 78, protein: 2.4, carbs: 4.5, fat: 5.8, fiber: 1.5, sugar: 0.1, sodium: 120, potassium: 90, calcium: 12, iron: 0.8, waterPercentage: 60),
  SeedFood(name: 'Guacamole', category: FoodCategory.healthySnacks, servingSize: '2 tbsp (30g)', servingGrams: 30, calories: 46, protein: 0.6, carbs: 2.5, fat: 4, fiber: 2, sugar: 0.2, sodium: 60, potassium: 150, calcium: 4, iron: 0.2, waterPercentage: 72),
  SeedFood(name: 'Trail Mix', category: FoodCategory.healthySnacks, servingSize: '1/4 cup (35g)', servingGrams: 35, calories: 175, protein: 5, carbs: 20, fat: 10, fiber: 2.5, sugar: 12, sodium: 40, potassium: 180, calcium: 30, iron: 1, waterPercentage: 6),
  SeedFood(name: 'Dried Apricots', category: FoodCategory.healthySnacks, servingSize: '5 pieces (35g)', servingGrams: 35, calories: 84, protein: 1.2, carbs: 22, fat: 0.2, fiber: 2.7, sugar: 18, sodium: 3, potassium: 420, calcium: 13, iron: 0.9, vitaminA: 100, waterPercentage: 30),
  SeedFood(name: 'Raisins', category: FoodCategory.healthySnacks, servingSize: '1/4 cup (40g)', servingGrams: 40, calories: 120, protein: 1.3, carbs: 32, fat: 0.2, fiber: 1.5, sugar: 24, sodium: 5, potassium: 320, calcium: 20, iron: 0.8, waterPercentage: 15),
  SeedFood(name: 'Veggie Sticks', category: FoodCategory.healthySnacks, servingSize: '1 cup (100g)', servingGrams: 100, calories: 35, protein: 1.5, carbs: 8, fat: 0.3, fiber: 3, sugar: 3, sodium: 40, potassium: 250, calcium: 25, iron: 0.5, vitaminC: 30, waterPercentage: 90),
  SeedFood(name: 'Fruit Salad', category: FoodCategory.healthySnacks, servingSize: '1 cup (200g)', servingGrams: 200, calories: 100, protein: 1.5, carbs: 25, fat: 0.5, fiber: 4, sugar: 18, sodium: 5, potassium: 350, calcium: 30, iron: 0.5, vitaminC: 40, waterPercentage: 85),
  SeedFood(name: 'Smoothie Bowl', category: FoodCategory.healthySnacks, servingSize: '1 bowl (300g)', servingGrams: 300, calories: 250, protein: 8, carbs: 45, fat: 5, fiber: 6, sugar: 25, sodium: 60, potassium: 500, calcium: 100, iron: 1, vitaminC: 30, waterPercentage: 75),
  SeedFood(name: 'Rice Crackers', category: FoodCategory.healthySnacks, servingSize: '10 pieces (30g)', servingGrams: 30, calories: 120, protein: 2, carbs: 24, fat: 1.5, fiber: 1, sugar: 1, sodium: 200, potassium: 30, calcium: 5, iron: 0.4, waterPercentage: 5),
];
