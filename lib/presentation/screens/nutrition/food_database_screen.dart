import 'dart:async';

import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/food_category.dart';
import '../../../domain/entities/food_item.dart';
import '../../../domain/entities/meal_category.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/nutrition_providers.dart';
import '../../router/app_router.dart';
import 'widgets/add_food_sheet.dart';
import 'widgets/food_tile.dart';

/// How the food database is entered.
enum FoodDatabaseMode {
  /// Browse: tapping a food opens its detail screen.
  browse,

  /// Pick: tapping a food immediately opens the "add to meal" sheet.
  pick,

  /// Template: tapping a food pops it back to a template builder.
  template,
}

/// Navigation extras for the food database route.
class FoodDatabaseArgs {
  const FoodDatabaseArgs({this.mode = FoodDatabaseMode.browse});

  const FoodDatabaseArgs.pick() : mode = FoodDatabaseMode.pick;

  const FoodDatabaseArgs.template() : mode = FoodDatabaseMode.template;

  final FoodDatabaseMode mode;
}

/// The food database: search, browse by category, favourites, recent and
/// frequent foods.
class FoodDatabaseScreen extends ConsumerStatefulWidget {
  const FoodDatabaseScreen({super.key, this.args = const FoodDatabaseArgs()});

  final FoodDatabaseArgs args;

  @override
  ConsumerState<FoodDatabaseScreen> createState() => _FoodDatabaseScreenState();
}

enum _FoodSection { catalog, favorites, recent, frequent }

class _FoodDatabaseScreenState extends ConsumerState<FoodDatabaseScreen> {
  final TextEditingController _searchController = TextEditingController();
  _FoodSection _section = _FoodSection.catalog;
  FoodCategory? _category;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final String text = _searchController.text;
    // Search always targets the catalog: typing while another section is
    // active silently switched the section to catalog instead of doing nothing.
    if (text.trim().isNotEmpty && _section != _FoodSection.catalog) {
      setState(() => _section = _FoodSection.catalog);
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(nutritionFoodSearchQueryProvider.notifier).state = text;
    });
  }

  void _clearFilters() {
    setState(() {
      _section = _FoodSection.catalog;
      _category = null;
    });
    _searchController.clear();
    ref.read(nutritionFoodFilterProvider.notifier).state =
        ref.read(nutritionFoodFilterProvider).copyWith(category: null);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool pick = widget.args.mode == FoodDatabaseMode.pick;

    return Scaffold(
      appBar: AppBar(
        title: Text(pick ? l10n.nutritionAddFood : l10n.nutritionFoodDatabase),
        actions: [
          IconButton(
            onPressed: _clearFilters,
            tooltip: l10n.commonClear,
            icon: const Icon(Icons.filter_alt_off_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.nutritionFoodSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: _searchController.clear,
                        ),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  _sectionChip(
                    label: l10n.nutritionAllFoods,
                    selected: _section == _FoodSection.catalog,
                    onTap: () => setState(() => _section = _FoodSection.catalog),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _sectionChip(
                    label: l10n.nutritionFavorites,
                    selected: _section == _FoodSection.favorites,
                    onTap: () =>
                        setState(() => _section = _FoodSection.favorites),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _sectionChip(
                    label: l10n.nutritionRecent,
                    selected: _section == _FoodSection.recent,
                    onTap: () => setState(() => _section = _FoodSection.recent),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _sectionChip(
                    label: l10n.nutritionFrequent,
                    selected: _section == _FoodSection.frequent,
                    onTap: () =>
                        setState(() => _section = _FoodSection.frequent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: FoodCategory.valuesInOrder
                    .map(
                      (FoodCategory category) => Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: FilterChip(
                          label: Text(_foodCategoryLabel(context, category)),
                          selected: _category == category,
                          showCheckmark: false,
                          onSelected: (_) {
                            setState(() => _category = category);
                            ref
                                .read(nutritionFoodFilterProvider.notifier)
                                .state = ref
                                    .read(nutritionFoodFilterProvider)
                                    .copyWith(category: category);
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _buildResults(context)),
          ],
        ),
      ),
    );
  }

  Widget _sectionChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final FoodDatabaseMode mode = widget.args.mode;
    switch (_section) {
      case _FoodSection.favorites:
        return _FoodList(
          key: const ValueKey<String>('favorites'),
          provider: nutritionFavoritesProvider,
          emptyTitle: context.l10n.nutritionNoFavorites,
          emptySubtitle: context.l10n.nutritionNoFavoritesSubtitle,
          mode: mode,
        );
      case _FoodSection.recent:
        return _FoodList(
          key: const ValueKey<String>('recent'),
          provider: nutritionRecentFoodsProvider,
          emptyTitle: context.l10n.nutritionNoRecent,
          emptySubtitle: context.l10n.nutritionNoRecentSubtitle,
          mode: mode,
        );
      case _FoodSection.frequent:
        return _FoodList(
          key: const ValueKey<String>('frequent'),
          provider: nutritionFrequentFoodsProvider,
          emptyTitle: context.l10n.nutritionNoFrequent,
          emptySubtitle: context.l10n.nutritionNoFrequentSubtitle,
          mode: mode,
        );
      case _FoodSection.catalog:
        return _CatalogResults(mode: mode);
    }
  }
}

/// Catalog browsing: search results when filtering, otherwise the full
/// catalog grouped by category.
class _CatalogResults extends ConsumerWidget {
  const _CatalogResults({required this.mode});

  final FoodDatabaseMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String query = ref.watch(nutritionFoodSearchQueryProvider);
    final bool filtering =
        query.trim().isNotEmpty ||
        (ref.watch(nutritionFoodFilterProvider).category != null);

    if (filtering) {
      return _FoodList(
        key: const ValueKey<String>('search'),
        provider: nutritionFoodSearchResultsProvider,
        emptyTitle: context.l10n.nutritionNoResults,
        emptySubtitle: context.l10n.nutritionNoResultsSubtitle,
        mode: mode,
      );
    }

    return _CatalogGrouped(mode: mode);
  }
}

class _CatalogGrouped extends ConsumerWidget {
  const _CatalogGrouped({required this.mode});

  final FoodDatabaseMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FoodItem>> async = ref.watch(nutritionCatalogProvider);

    return async.when(
      loading: () => const LoadingWidget(),
      error: (Object error, StackTrace stackTrace) => ErrorWidget(
        title: context.l10n.errorDatabase,
        subtitle: context.l10n.errorDatabaseSubtitle,
        onRetry: () => ref.invalidate(nutritionCatalogProvider),
      ),
      data: (List<FoodItem> foods) {
        if (foods.isEmpty) {
          return _EmptyState(
            title: context.l10n.nutritionNoResults,
            subtitle: context.l10n.nutritionNoResultsSubtitle,
          );
        }

        final List<FoodItem> sorted = List<FoodItem>.of(foods)
          ..sort((FoodItem a, FoodItem b) {
            final int byCategory = a.categoryEnum.index.compareTo(
              b.categoryEnum.index,
            );
            if (byCategory != 0) return byCategory;
            return a.name.compareTo(b.name);
          });

        final List<Widget> sections = <Widget>[];
        FoodCategory? current;
        for (final FoodItem food in sorted) {
          if (food.categoryEnum != current) {
            current = food.categoryEnum;
            sections.add(
              _CategoryHeader(label: _foodCategoryLabel(context, current)),
            );
          }
          sections.add(
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _buildTile(context, ref, food, mode),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: sections,
        );
      },
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.sm, 4, AppSpacing.xs),
      child: Text(
        label,
        style: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// A scrollable food list driven by an [AutoDisposeFutureProvider].
class _FoodList extends ConsumerWidget {
  const _FoodList({
    super.key,
    required this.provider,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.mode,
  });

  final AutoDisposeFutureProvider<List<FoodItem>> provider;
  final String emptyTitle;
  final String emptySubtitle;
  final FoodDatabaseMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FoodItem>> async = ref.watch(provider);

    return async.when(
      loading: () => const LoadingWidget(),
      error: (Object error, StackTrace stackTrace) => ErrorWidget(
        title: context.l10n.errorDatabase,
        subtitle: context.l10n.errorDatabaseSubtitle,
        onRetry: () => ref.invalidate(provider),
      ),
      data: (List<FoodItem> foods) {
        if (foods.isEmpty) {
          return _EmptyState(title: emptyTitle, subtitle: emptySubtitle);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          itemCount: foods.length,
          itemBuilder: (BuildContext context, int index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _buildTile(context, ref, foods[index], mode),
            );
          },
        );
      },
    );
  }
}

Widget _buildTile(
  BuildContext context,
  WidgetRef ref,
  FoodItem food,
  FoodDatabaseMode mode,
) {
  Future<void> onTap() async {
    switch (mode) {
      case FoodDatabaseMode.browse:
        context.push(AppRoutes.foodDetailPath(food.id!));
      case FoodDatabaseMode.pick:
        final AsyncValue<List<MealCategory>> categories = ref.read(
          nutritionMealCategoriesProvider,
        );
        await showAddFoodSheet(
          context,
          food: food,
          mealCategories: categories.valueOrNull ?? const <MealCategory>[],
          date: ref.read(nutritionSelectedDateProvider),
        );
      case FoodDatabaseMode.template:
        Navigator.of(context).pop(food);
    }
  }

  return FoodTile(
    food: food,
    onTap: onTap,
    onFavoriteTap: () => toggleFoodFavorite(ref, food.id!),
    trailing: mode == FoodDatabaseMode.template
        ? const Icon(Icons.add_circle_rounded, size: 20)
        : null,
  );
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
              Icons.no_meals_rounded,
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

String _foodCategoryLabel(BuildContext context, FoodCategory category) {
  final AppLocalizations l10n = context.l10n;
  switch (category) {
    case FoodCategory.rice:
      return l10n.foodCategoryRice;
    case FoodCategory.bread:
      return l10n.foodCategoryBread;
    case FoodCategory.meat:
      return l10n.foodCategoryMeat;
    case FoodCategory.chicken:
      return l10n.foodCategoryChicken;
    case FoodCategory.fish:
      return l10n.foodCategoryFish;
    case FoodCategory.egg:
      return l10n.foodCategoryEgg;
    case FoodCategory.vegetables:
      return l10n.foodCategoryVegetables;
    case FoodCategory.fruits:
      return l10n.foodCategoryFruits;
    case FoodCategory.milk:
      return l10n.foodCategoryMilk;
    case FoodCategory.dairy:
      return l10n.foodCategoryDairy;
    case FoodCategory.fastFood:
      return l10n.foodCategoryFastFood;
    case FoodCategory.dessert:
      return l10n.foodCategoryDessert;
    case FoodCategory.drinks:
      return l10n.foodCategoryDrinks;
    case FoodCategory.nuts:
      return l10n.foodCategoryNuts;
    case FoodCategory.seeds:
      return l10n.foodCategorySeeds;
    case FoodCategory.healthySnacks:
      return l10n.foodCategoryHealthySnacks;
  }
}

