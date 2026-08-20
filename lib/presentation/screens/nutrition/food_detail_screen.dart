import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/food_item.dart';
import '../../../domain/entities/meal_category.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/nutrition_providers.dart';
import 'widgets/add_food_sheet.dart';
import 'widgets/calorie_ring.dart';
import 'widgets/macro_donut_chart.dart';

/// Detail view of a single food: nutrition facts and add-to-meal action.
class FoodDetailScreen extends ConsumerWidget {
  const FoodDetailScreen({super.key, required this.foodId});

  final int foodId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FoodItem>> async = ref.watch(nutritionCatalogProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.nutritionFoodDatabase)),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(nutritionCatalogProvider),
        ),
        data: (List<FoodItem> foods) {
          FoodItem? food;
          for (final FoodItem candidate in foods) {
            if (candidate.id == foodId) {
              food = candidate;
              break;
            }
          }
          if (food == null) {
            return ErrorWidget(
              title: context.l10n.errorDatabase,
              subtitle: context.l10n.errorDatabaseSubtitle,
              onRetry: () => ref.invalidate(nutritionCatalogProvider),
            );
          }
          return _FoodDetailContent(food: food);
        },
      ),
    );
  }
}

class _FoodDetailContent extends ConsumerWidget {
  const _FoodDetailContent({required this.food});

  final FoodItem food;

  Future<void> _addToMeal(BuildContext context, WidgetRef ref) async {
    final AsyncValue<List<MealCategory>> categories = ref.read(
      nutritionMealCategoriesProvider,
    );
    if (categories.valueOrNull == null || categories.valueOrNull!.isEmpty) {
      AppSnackbar.error(context, context.l10n.nutritionSelectMeal);
      return;
    }
    await showAddFoodSheet(
      context,
      food: food,
      mealCategories: categories.valueOrNull!,
      date: ref.read(nutritionSelectedDateProvider),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                children: [
                  _HeaderCard(
                    food: food,
                    onFavoriteTap: () {
                      toggleFoodFavorite(ref, food.id!);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FactsCard(food: food),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () => _addToMeal(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.nutritionAddToMeal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.food, required this.onFavoriteTap});

  final FoodItem food;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return AppCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (food.brand != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        food.brand!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${l10n.nutritionServingSize}: '
                      '${food.servingSize ?? '${food.servingGrams?.round() ?? 0}g'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFavoriteTap,
                icon: Icon(
                  food.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: food.isFavorite
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          CalorieRing(
            value: food.calories / 500,
            size: 132,
            strokeWidth: 11,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  food.calories.round().toString().toBanglaDigits(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  l10n.nutritionKcal,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          MacroDonutChart(
            slices: <MacroSlice>[
              MacroSlice(
                value: food.protein,
                color: theme.colorScheme.primary,
                label: l10n.nutritionProtein,
              ),
              MacroSlice(
                value: food.carbs,
                color: theme.colorScheme.secondary,
                label: l10n.nutritionCarbs,
              ),
              MacroSlice(
                value: food.fat,
                color: theme.colorScheme.tertiary,
                label: l10n.nutritionFat,
              ),
            ],
            size: 120,
            centerTitle: food.protein.round().toString().toBanglaDigits(),
            centerSubtitle: l10n.nutritionProtein,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MacroStat(
                label: l10n.nutritionProtein,
                value: '${food.protein.toStringAsFixed(1).toBanglaDigits()}g',
                color: theme.colorScheme.primary,
              ),
              _MacroStat(
                label: l10n.nutritionCarbs,
                value: '${food.carbs.toStringAsFixed(1).toBanglaDigits()}g',
                color: theme.colorScheme.secondary,
              ),
              _MacroStat(
                label: l10n.nutritionFat,
                value: '${food.fat.toStringAsFixed(1).toBanglaDigits()}g',
                color: theme.colorScheme.tertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  const _MacroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.food});

  final FoodItem food;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    final List<(String, String)> rows = <(String, String)>[
      (l10n.nutritionCalories, '${food.calories.round().toString().toBanglaDigits()} ${l10n.dashboardKcalUnit}'),
      (l10n.nutritionProtein, '${food.protein.toStringAsFixed(1).toBanglaDigits()}g'),
      (l10n.nutritionCarbs, '${food.carbs.toStringAsFixed(1).toBanglaDigits()}g'),
      (l10n.nutritionFat, '${food.fat.toStringAsFixed(1).toBanglaDigits()}g'),
      (l10n.nutritionFiber, '${food.fiber.toStringAsFixed(1).toBanglaDigits()}g'),
      (l10n.nutritionSugar, '${food.sugar.toStringAsFixed(1).toBanglaDigits()}g'),
      (l10n.nutritionSodium, '${food.sodium.toStringAsFixed(0).toBanglaDigits()}mg'),
      (l10n.nutritionPotassium, '${food.potassium.toStringAsFixed(0).toBanglaDigits()}mg'),
      (l10n.nutritionCalcium, '${food.calcium.toStringAsFixed(0).toBanglaDigits()}mg'),
      (l10n.nutritionIron, '${food.iron.toStringAsFixed(1).toBanglaDigits()}mg'),
      (l10n.nutritionVitaminA, '${food.vitaminA.toStringAsFixed(0).toBanglaDigits()}mcg'),
      (l10n.nutritionVitaminC, '${food.vitaminC.toStringAsFixed(1).toBanglaDigits()}mg'),
      (l10n.nutritionWaterContent, '${food.waterPercentage.toStringAsFixed(0).toBanglaDigits()}%'),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.nutritionNutritionFacts,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          ...rows.map(
            ((String, String) row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      row.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      row.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


