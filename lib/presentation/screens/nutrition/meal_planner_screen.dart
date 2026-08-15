import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/dialogs/app_dialog.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/food_item.dart';
import '../../../domain/entities/meal_category.dart';
import '../../../domain/entities/meal_template_detail.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/nutrition_providers.dart';
import '../../router/app_router.dart';
import 'widgets/food_tile.dart';
import 'widgets/meal_category_icon.dart';
import 'widgets/quantity_stepper.dart';
import 'food_database_screen.dart';

/// Meal Planner: saved meal templates that can be logged into a day in one
/// tap or reused to build new templates.
class MealPlannerScreen extends ConsumerWidget {
  const MealPlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MealTemplateDetail>> async = ref.watch(
      nutritionMealTemplatesProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.nutritionMealPlanner)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBuilder(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.nutritionNewTemplate),
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(nutritionMealTemplatesProvider),
        ),
        data: (List<MealTemplateDetail> templates) {
          if (templates.isEmpty) {
            return _EmptyState(
              title: context.l10n.nutritionNoTemplates,
              subtitle: context.l10n.nutritionNoTemplatesSubtitle,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: templates.map(
              (MealTemplateDetail template) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _TemplateCard(
                  template: template,
                  onLog: () => _logTemplate(context, ref, template.meal.id!),
                  onDelete: () => _deleteTemplate(context, ref, template),
                ),
              ),
            ).toList(),
          );
        },
      ),
    );
  }

  Future<void> _openBuilder(BuildContext context, WidgetRef ref) async {
    final AsyncValue<List<MealCategory>> categories = ref.read(
      nutritionMealCategoriesProvider,
    );
    final List<MealCategory> meals =
        categories.valueOrNull ?? const <MealCategory>[];
    if (meals.isEmpty) {
      AppSnackbar.error(context, context.l10n.errorDatabase);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => _TemplateBuilderSheet(meals: meals),
    );
    ref.invalidate(nutritionMealTemplatesProvider);
  }

  Future<void> _logTemplate(
    BuildContext context,
    WidgetRef ref,
    int mealId,
  ) async {
    await logMealTemplate(ref, mealId);
    if (!context.mounted) return;
    AppSnackbar.success(context, context.l10n.nutritionTemplateLogged);
  }

  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    MealTemplateDetail template,
  ) async {
    final bool? ok = await AppDialog.confirm(
      context: context,
      title: context.l10n.nutritionDeleteTemplate,
      message: context.l10n.nutritionDeleteTemplateMessage(template.meal.name),
      confirmLabel: context.l10n.commonDelete,
      destructive: true,
    );
    if (ok == true) {
      await deleteMealTemplate(ref, template.meal.id!);
      if (!context.mounted) return;
      AppSnackbar.success(context, context.l10n.nutritionTemplateDeleted);
    }
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onLog,
    required this.onDelete,
  });

  final MealTemplateDetail template;
  final VoidCallback onLog;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.meal.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (template.category != null) ...[
                      const SizedBox(height: 2),
Text(
                        mealCategoryLabel(template.category!, l10n),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
'${template.items.length.toString().toBanglaDigits()} '
            '${l10n.nutritionItems} · '
            '${template.calories.round().toString().toBanglaDigits()} '
            '${l10n.dashboardKcalUnit}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...template.items.take(3).map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Text(
                    '${item.quantity.toStringAsFixed(1).toBanglaDigits()}×',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _foodName(template, item.foodItemId),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (template.items.length > 3)
            Text(
              '+ ${(template.items.length - 3).toString().toBanglaDigits()}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            onPressed: onLog,
            label: l10n.nutritionLogTemplate,
            icon: Icons.playlist_add_rounded,
            size: AppButtonSize.small,
          ),
        ],
      ),
    );
  }

  String _foodName(MealTemplateDetail template, int foodItemId) {
    for (final FoodItem food in template.foods) {
      if (food.id == foodItemId) return food.name;
    }
    return '#$foodItemId';
  }
}

/// Bottom sheet used to build a new meal template: pick foods, adjust
/// quantities and save.
class _TemplateBuilderSheet extends ConsumerStatefulWidget {
  const _TemplateBuilderSheet({required this.meals});

  final List<MealCategory> meals;

  @override
  ConsumerState<_TemplateBuilderSheet> createState() =>
      _TemplateBuilderSheetState();
}

class _TemplateBuilderSheetState extends ConsumerState<_TemplateBuilderSheet> {
  final TextEditingController _nameController = TextEditingController();
  final List<FoodItem> _foods = <FoodItem>[];
  final List<double> _quantities = <double>[];
  int? _mealTypeId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.meals.isNotEmpty) {
      _mealTypeId = widget.meals.first.id;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

Future<void> _addFood(BuildContext context) async {
    final FoodItem? picked = await context.push<FoodItem>(
      AppRoutes.foodDatabase,
      extra: const FoodDatabaseArgs.template(),
    );
    if (picked != null && mounted) {
      setState(() {
        _foods.add(picked);
        _quantities.add(1);
      });
    }
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackbar.error(context, context.l10n.nutritionTemplateNameRequired);
      return;
    }
    if (_mealTypeId == null) {
      AppSnackbar.error(context, context.l10n.nutritionSelectMeal);
      return;
    }
    if (_foods.isEmpty) {
      AppSnackbar.error(context, context.l10n.nutritionTemplateNoFoods);
      return;
    }
    setState(() => _saving = true);
    try {
      await saveMealTemplate(
        ref,
        name: name,
        categoryId: _mealTypeId!,
        foods: _foods,
        quantities: _quantities,
      );
      if (mounted) {
        Navigator.of(context).pop();
        AppSnackbar.success(context, context.l10n.nutritionTemplateSaved);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
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
                  l10n.nutritionNewTemplate,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.nutritionTemplateName,
                    hintText: l10n.nutritionTemplateNameHint,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.meals.map((MealCategory category) {
return ChoiceChip(
                      label: Text(mealCategoryLabel(category, l10n)),
                      selected: category.id == _mealTypeId,
                      onSelected: (_) =>
                          setState(() => _mealTypeId = category.id),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.nutritionSelectedFoods(
                        _foods.length.toString().toBanglaDigits(),
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _addFood(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(l10n.nutritionAddFood),
                    ),
                  ],
                ),
                if (_foods.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      l10n.nutritionTemplateNoFoods,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ...List<Widget>.generate(_foods.length, (int index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
child: FoodTile(
                        food: _foods[index],
                        showFavorite: false,
                        onTap: () {
                          final int? foodId = _foods[index].id;
                          if (foodId != null) {
                            context.push(AppRoutes.foodDetailPath(foodId));
                          }
                        },
                        trailing: QuantityStepper(
                          quantity: _quantities[index],
                          onChanged: (double value) {
                            setState(() => _quantities[index] = value);
                          },
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  onPressed: _saving ? null : _save,
                  label: l10n.nutritionSaveTemplate,
                  icon: Icons.save_rounded,
                  isLoading: _saving,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: context.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


