import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback/empty_widget.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../core/widgets/layout/custom_app_bar.dart';
import '../../../domain/entities/common_enums.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/exercise_category.dart';
import '../../../domain/entities/exercise_filter.dart';
import '../../../domain/entities/exercise_library.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/exercise_providers.dart';
import '../../router/app_router.dart';
import 'widgets/exercise_card.dart';
import 'widgets/exercise_cover.dart';

/// Searchable, filterable library of exercises grouped by muscle category.
class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  ExerciseCategory? _category;
  Difficulty? _difficulty;
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(exerciseSearchQueryProvider.notifier).state = value;
  }

  void _resetFilters() {
    _searchController.clear();
    _category = null;
    _difficulty = null;
    _favoritesOnly = false;
    ref.read(exerciseSearchQueryProvider.notifier).state = '';
    ref
        .read(exerciseFilterProvider.notifier)
        .state = const ExerciseFilter();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<ExerciseLibraryData> library = ref.watch(
      exerciseLibraryControllerProvider,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(title: l10n.exerciseLibrary, showBackButton: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.exerciseSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            library.when(
              data: (ExerciseLibraryData data) => _FilterBar(
                categories: data.categories,
                selectedCategory: _category,
                selectedDifficulty: _difficulty,
                favoritesOnly: _favoritesOnly,
                onCategoryChanged: (ExerciseCategory? value) {
                  setState(() => _category = value);
                  ref.read(exerciseFilterProvider.notifier).state = ExerciseFilter(
                    query: ref.read(exerciseSearchQueryProvider),
                    category: value,
                    difficulty: _difficulty,
                    favoritesOnly: _favoritesOnly,
                  );
                },
                onDifficultyChanged: (Difficulty? value) {
                  setState(() => _difficulty = value);
                  ref.read(exerciseFilterProvider.notifier).state = ExerciseFilter(
                    query: ref.read(exerciseSearchQueryProvider),
                    category: _category,
                    difficulty: value,
                    favoritesOnly: _favoritesOnly,
                  );
                },
                onFavoritesChanged: (bool value) {
                  setState(() => _favoritesOnly = value);
                  ref.read(exerciseFilterProvider.notifier).state = ExerciseFilter(
                    query: ref.read(exerciseSearchQueryProvider),
                    category: _category,
                    difficulty: _difficulty,
                    favoritesOnly: value,
                  );
                },
                onClear: _resetFilters,
              ),
              error: (Object error, StackTrace stackTrace) =>
                  const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: _ResultsList(
                favoritesOnly: _favoritesOnly,
                onClearFilters: _resetFilters,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.categories,
    required this.selectedCategory,
    required this.selectedDifficulty,
    required this.favoritesOnly,
    required this.onCategoryChanged,
    required this.onDifficultyChanged,
    required this.onFavoritesChanged,
    required this.onClear,
  });

  final List<ExerciseCategory> categories;
  final ExerciseCategory? selectedCategory;
  final Difficulty? selectedDifficulty;
  final bool favoritesOnly;
  final ValueChanged<ExerciseCategory?> onCategoryChanged;
  final ValueChanged<Difficulty?> onDifficultyChanged;
  final ValueChanged<bool> onFavoritesChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: categories.length + 1,
            separatorBuilder: (BuildContext context, int index) =>
                AppSpacing.sm.widthSpace,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return _CategoryChip(
                  label: l10n.exerciseAll,
                  icon: Icons.apps_rounded,
                  colorValue: null,
                  selected: selectedCategory == null,
                  onTap: () => onCategoryChanged(null),
                );
              }
              final ExerciseCategory category = categories[index - 1];
              return _CategoryChip(
                label: category.name,
                icon: exerciseCategoryIconFor(category),
                colorValue: category.colorValue,
                selected: selectedCategory == category,
                onTap: () => onCategoryChanged(category),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FilterChip(
                label: l10n.workoutFilterAll,
                selected: selectedDifficulty == null,
                onTap: () => onDifficultyChanged(null),
              ),
              _FilterChip(
                label: l10n.workoutDifficultyBeginner,
                selected: selectedDifficulty == Difficulty.beginner,
                onTap: () => onDifficultyChanged(Difficulty.beginner),
              ),
              _FilterChip(
                label: l10n.workoutDifficultyIntermediate,
                selected: selectedDifficulty == Difficulty.intermediate,
                onTap: () => onDifficultyChanged(Difficulty.intermediate),
              ),
              _FilterChip(
                label: l10n.workoutDifficultyAdvanced,
                selected: selectedDifficulty == Difficulty.advanced,
                onTap: () => onDifficultyChanged(Difficulty.advanced),
              ),
              _FilterChip(
                label: l10n.exerciseFavoritesOnly,
                icon: favoritesOnly
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                selected: favoritesOnly,
                onTap: () => onFavoritesChanged(!favoritesOnly),
              ),
              if (selectedCategory != null ||
                  selectedDifficulty != null ||
                  favoritesOnly)
                _FilterChip(
                  label: l10n.workoutClearFilters,
                  icon: Icons.filter_alt_off_rounded,
                  selected: false,
                  onTap: onClear,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.colorValue,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int? colorValue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = colorValue != null
        ? Color(colorValue!)
        : context.colorScheme.primary;

    return SizedBox(
      width: 76,
      child: InkWell(
        borderRadius: AppRadius.mdRadius,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdRadius,
                color: selected ? color : color.withValues(alpha: 0.14),
                border: Border.all(
                  color: selected
                      ? color
                      : color.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label.capitalize(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.textTheme.labelSmall?.copyWith(
                color: selected
                    ? context.colorScheme.onSurface
                    : context.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 18,
              color: selected
                  ? context.colorScheme.onSecondaryContainer
                  : context.colorScheme.onSurfaceVariant,
            ),
      selectedColor: context.colorScheme.secondaryContainer,
      onSelected: (bool value) => onTap(),
    );
  }
}

class _ResultsList extends ConsumerWidget {
  const _ResultsList({
    required this.favoritesOnly,
    required this.onClearFilters,
  });

  final bool favoritesOnly;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<Exercise>> async = ref.watch(
      exerciseSearchResultsProvider,
    );

    return async.when(
      data: (List<Exercise> exercises) {
        if (exercises.isEmpty) {
          return favoritesOnly
              ? EmptyWidget(
                  title: l10n.exerciseNoFavorites,
                  subtitle: l10n.exerciseNoFavoritesSubtitle,
                  icon: Icons.favorite_border_rounded,
                )
              : EmptyWidget(
                  title: l10n.exerciseNoResults,
                  subtitle: l10n.exerciseNoResultsSubtitle,
                  icon: Icons.search_off_rounded,
                );
        }

        return RefreshIndicator(
          onRefresh: () =>
              ref.read(exerciseLibraryControllerProvider.notifier).refresh(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            itemCount: exercises.length,
            separatorBuilder: (BuildContext context, int index) =>
                AppSpacing.sm.heightSpace,
            itemBuilder: (BuildContext context, int index) {
              final Exercise exercise = exercises[index];
              return ExerciseCard(
                exercise: exercise,
                onTap: () => context.push(
                  AppRoutes.exerciseDetailPath(exercise.id!),
                ),
                onFavorite: () =>
                    toggleExerciseFavorite(ref, exercise.id!),
              );
            },
          ),
        );
      },
      error: (Object error, StackTrace stackTrace) => ErrorWidget(
        title: l10n.errorDatabase,
        subtitle: l10n.errorDatabaseSubtitle,
        onRetry: () => ref.invalidate(exerciseSearchResultsProvider),
      ),
      loading: () => const LoadingWidget(message: null),
    );
  }
}
