import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../domain/entities/food_item.dart';
import '../../../../domain/entities/meal_category.dart';
import '../../../providers/nutrition_providers.dart';
import 'quantity_stepper.dart';
import 'meal_category_icon.dart';

/// Presents the "add food to a meal slot" bottom sheet and handles logging.
Future<void> showAddFoodSheet(
  BuildContext context, {
  required FoodItem food,
  required List<MealCategory> mealCategories,
  DateTime? date,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _AddFoodSheet(
      food: food,
      mealCategories: mealCategories,
      date: date,
    ),
  );
}

class _AddFoodSheet extends ConsumerStatefulWidget {
  const _AddFoodSheet({
    required this.food,
    required this.mealCategories,
    this.date,
  });

  final FoodItem food;
  final List<MealCategory> mealCategories;
  final DateTime? date;

  @override
  ConsumerState<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends ConsumerState<_AddFoodSheet> {
  double _quantity = 1;
  int? _mealTypeId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.mealCategories.isNotEmpty) {
      _mealTypeId = widget.mealCategories.first.id;
    }
  }

  Future<void> _submit() async {
    if (_mealTypeId == null) {
      AppSnackbar.error(context, context.l10n.nutritionSelectMeal);
      return;
    }
    setState(() => _submitting = true);
    try {
      await addFoodToLog(
        ref,
        food: widget.food,
        mealTypeId: _mealTypeId!,
        quantity: _quantity,
        date: widget.date,
      );
      if (mounted) {
        Navigator.of(context).pop();
        AppSnackbar.success(context, context.l10n.nutritionFoodAdded);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double totalCalories = widget.food.calories * _quantity;
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  context.l10n.nutritionAddToMeal,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${widget.food.name} · ${widget.food.servingSize ?? ''}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  context.l10n.nutritionMealType,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.mealCategories.map((MealCategory category) {
                    final bool selected = category.id == _mealTypeId;
return ChoiceChip(
                      label: Text(mealCategoryLabel(category, context.l10n)),
                      selected: selected,
                      onSelected: (_) => setState(() => _mealTypeId = category.id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.nutritionQuantity,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    QuantityStepper(
                      quantity: _quantity,
                      onChanged: (double value) => setState(() => _quantity = value),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.nutritionCalories,
                      style: theme.textTheme.labelLarge,
                    ),
                    Text(
                      '${totalCalories.round().toString().toBanglaDigits()} '
                      '${context.l10n.dashboardKcalUnit}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  onPressed: _submitting ? null : _submit,
                  label: context.l10n.nutritionAddToLog,
                  icon: Icons.add_rounded,
                  isLoading: _submitting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

