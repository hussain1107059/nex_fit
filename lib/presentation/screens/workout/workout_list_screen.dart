import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback/empty_widget.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../core/widgets/fields/app_text_field.dart';
import '../../../core/widgets/layout/custom_app_bar.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/common_enums.dart';
import '../../../domain/entities/workout.dart';
import '../../../domain/entities/workout_category.dart';
import '../../../domain/entities/workout_filter.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workout_providers.dart';
import '../../router/app_router.dart';
import 'widgets/workout_card.dart';

/// Shared screen for browsing, searching and filtering the workout library.
class WorkoutListScreen extends ConsumerStatefulWidget {
  const WorkoutListScreen({super.key, this.args = const WorkoutListArgs.all()});

  final WorkoutListArgs args;

  @override
  ConsumerState<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends ConsumerState<WorkoutListScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.args.searchMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(workoutSearchQueryProvider.notifier).state = '';
        ref.read(workoutSearchFilterProvider.notifier).state =
            const WorkoutFilter();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String title = widget.args.title ??
        (widget.args.searchMode
            ? l10n.workoutSearchTitle
            : widget.args.favoritesOnly
            ? l10n.workoutFavorites
            : l10n.tabWorkout);

    final Widget body;
    if (widget.args.searchMode) {
      body = const _SearchBody();
    } else {
      body = _BrowseBody(args: widget.args);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: title,
              showBackButton: true,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _BrowseBody extends ConsumerWidget {
  const _BrowseBody({required this.args});

  final WorkoutListArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      return const SizedBox.shrink();
    }

    final FutureProvider<List<Workout>> source;
    if (args.favoritesOnly) {
      source = FutureProvider.autoDispose<List<Workout>>(
        (ref) => ref.watch(workoutRepositoryProvider).getFavorites(user.id),
      );
    } else if (args.categorySlug != null) {
      final String slug = args.categorySlug!;
      source = FutureProvider.autoDispose<List<Workout>>(
        (ref) => ref
            .watch(workoutLibraryRepositoryProvider)
            .getByCategory(user.id, slug),
      );
    } else {
      source = FutureProvider.autoDispose<List<Workout>>(
        (ref) => ref.watch(workoutRepositoryProvider).getByUserId(user.id),
      );
    }

    return ref.watch(source).when(
      data: (List<Workout> workouts) => _WorkoutResults(workouts: workouts),
      error: (Object error, StackTrace stackTrace) => ErrorWidget(
        title: context.l10n.errorDatabase,
        onRetry: () => ref.invalidate(source),
      ),
      loading: () => const LoadingWidget(),
    );
  }
}

class _SearchBody extends ConsumerStatefulWidget {
  const _SearchBody();

  @override
  ConsumerState<_SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends ConsumerState<_SearchBody> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final WorkoutFilter filter = ref.watch(workoutSearchFilterProvider);
    final String query = ref.watch(workoutSearchQueryProvider);
    final bool active = query.trim().isNotEmpty || !filter.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: AppTextField(
            controller: _controller,
            hintText: l10n.workoutSearchHint,
            prefixIcon: Icons.search_rounded,
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _controller.clear();
                      ref.read(workoutSearchQueryProvider.notifier).state = '';
                    },
                    icon: const Icon(Icons.close_rounded),
                    tooltip: context.l10n.commonClear,
                  )
                : null,
            onChanged: (String value) {
              ref.read(workoutSearchQueryProvider.notifier).state = value;
            },
            textInputAction: TextInputAction.search,
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              _FilterChipButton(
                label: l10n.workoutFilterDifficulty,
                icon: Icons.military_tech_rounded,
                selected: filter.difficulty != null,
                onTap: () => _showDifficultyPicker(),
              ),
              AppSpacing.xs.widthSpace,
              _FilterChipButton(
                label: _durationLabel(l10n, filter.duration),
                icon: Icons.schedule_rounded,
                selected: filter.duration != WorkoutDurationFilter.any,
                onTap: () => _showDurationPicker(),
              ),
              AppSpacing.xs.widthSpace,
              _FilterChipButton(
                label: l10n.workoutFilterGoal,
                icon: Icons.flag_rounded,
                selected: filter.goal != null,
                onTap: () => _showGoalPicker(),
              ),
              AppSpacing.xs.widthSpace,
              _FilterChipButton(
                label: l10n.workoutFilterEquipment,
                icon: Icons.fitness_center_rounded,
                selected: filter.equipment != null,
                onTap: () => _showEquipmentPicker(),
              ),
              if (active) ...[
                AppSpacing.xs.widthSpace,
                _FilterChipButton(
                  label: l10n.workoutClearFilters,
                  icon: Icons.filter_alt_off_rounded,
                  onTap: () {
                    _controller.clear();
                    ref.read(workoutSearchQueryProvider.notifier).state = '';
                    ref.read(workoutSearchFilterProvider.notifier).state =
                        const WorkoutFilter();
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ref.watch(workoutSearchResultsProvider).when(
            data: (List<Workout> workouts) {
              if (!active) {
                return EmptyWidget(
                  title: l10n.workoutSearchEmptyTitle,
                  subtitle: l10n.workoutSearchEmptySubtitle,
                  icon: Icons.search_rounded,
                );
              }
              if (workouts.isEmpty) {
                return EmptyWidget(
                  title: l10n.emptyNoResults,
                  subtitle: l10n.emptyNoResultsSubtitle,
                  icon: Icons.search_off_rounded,
                );
              }
              return _WorkoutResults(workouts: workouts);
            },
            error: (Object error, StackTrace stackTrace) => ErrorWidget(
              title: l10n.errorDatabase,
              onRetry: () =>
                  ref.invalidate(workoutSearchResultsProvider),
            ),
            loading: () => const LoadingWidget(),
          ),
        ),
      ],
    );
  }

  String _durationLabel(
    AppLocalizations l10n,
    WorkoutDurationFilter duration,
  ) {
    return switch (duration) {
      WorkoutDurationFilter.any => l10n.workoutFilterDuration,
      WorkoutDurationFilter.short => l10n.workoutFilterShort,
      WorkoutDurationFilter.medium => l10n.workoutFilterMedium,
      WorkoutDurationFilter.long => l10n.workoutFilterLong,
    };
  }

  Future<void> _showDifficultyPicker() async {
    final WorkoutFilter filter = ref.read(workoutSearchFilterProvider);
    final Difficulty? selected = await showModalBottomSheet<Difficulty>(
      context: context,
      builder: (BuildContext context) => _PickerSheet<Difficulty?>(
        title: context.l10n.workoutFilterDifficulty,
        options: <_PickerOption<Difficulty?>>[
          _PickerOption<Difficulty?>(
            label: context.l10n.workoutFilterAll,
            value: null,
            selected: filter.difficulty == null,
          ),
          for (final Difficulty difficulty in Difficulty.values)
            _PickerOption<Difficulty?>(
              label: difficultyLabel(context, difficulty),
              value: difficulty,
              selected: filter.difficulty == difficulty,
            ),
        ],
      ),
    );
    if (selected != null) {
      ref
          .read(workoutSearchFilterProvider.notifier)
          .state = filter.copyWith(difficulty: selected);
    }
  }

  Future<void> _showDurationPicker() async {
    final WorkoutFilter filter = ref.read(workoutSearchFilterProvider);
    final WorkoutDurationFilter? selected =
        await showModalBottomSheet<WorkoutDurationFilter>(
          context: context,
          builder: (BuildContext context) => _PickerSheet<WorkoutDurationFilter>(
            title: context.l10n.workoutFilterDuration,
            options: <_PickerOption<WorkoutDurationFilter>>[
              for (final WorkoutDurationFilter duration
                  in WorkoutDurationFilter.values)
                _PickerOption<WorkoutDurationFilter>(
                  label: _durationLabel(context.l10n, duration),
                  value: duration,
                  selected: filter.duration == duration,
                ),
            ],
          ),
        );
    if (selected != null) {
      ref
          .read(workoutSearchFilterProvider.notifier)
          .state = filter.copyWith(duration: selected);
    }
  }

  Future<void> _showGoalPicker() async {
    final WorkoutFilter filter = ref.read(workoutSearchFilterProvider);
    final String? selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (BuildContext context) => _PickerSheet<String?>(
        title: context.l10n.workoutFilterGoal,
        options: <_PickerOption<String?>>[
          _PickerOption<String?>(
            label: context.l10n.workoutFilterAll,
            value: null,
            selected: filter.goal == null,
          ),
          _PickerOption<String?>(
            label: context.l10n.goalWeightLoss,
            value: GoalType.weightLoss.name,
            selected: filter.goal == GoalType.weightLoss.name,
          ),
          _PickerOption<String?>(
            label: context.l10n.goalMuscleGain,
            value: GoalType.muscleBuilding.name,
            selected: filter.goal == GoalType.muscleBuilding.name,
          ),
          _PickerOption<String?>(
            label: context.l10n.goalMaintainWeight,
            value: GoalType.maintainWeight.name,
            selected: filter.goal == GoalType.maintainWeight.name,
          ),
          _PickerOption<String?>(
            label: context.l10n.goalGeneralFitness,
            value: GoalType.generalFitness.name,
            selected: filter.goal == GoalType.generalFitness.name,
          ),
        ],
      ),
    );
    if (selected != null) {
      ref
          .read(workoutSearchFilterProvider.notifier)
          .state = filter.copyWith(goal: selected);
    }
  }

  Future<void> _showEquipmentPicker() async {
    const List<String> equipment = <String>[
      'None',
      'Dumbbell',
      'Barbell',
      'Kettlebell',
      'Resistance Band',
      'Yoga Mat',
      'Treadmill',
      'Exercise Ball',
    ];
    final WorkoutFilter filter = ref.read(workoutSearchFilterProvider);
    final String? selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (BuildContext context) => _PickerSheet<String?>(
        title: context.l10n.workoutFilterEquipment,
        options: <_PickerOption<String?>>[
          _PickerOption<String?>(
            label: context.l10n.workoutFilterAll,
            value: null,
            selected: filter.equipment == null,
          ),
          for (final String item in equipment)
            _PickerOption<String?>(
              label: item,
              value: item,
              selected: filter.equipment == item,
            ),
        ],
      ),
    );
    if (selected != null) {
      ref
          .read(workoutSearchFilterProvider.notifier)
          .state = filter.copyWith(equipment: selected);
    }
  }
}

class _WorkoutResults extends ConsumerWidget {
  const _WorkoutResults({required this.workouts});

  final List<Workout> workouts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WorkoutLibraryData> library =
        ref.watch(workoutLibraryControllerProvider);
    final Map<int, WorkoutCategory> categoriesById =
        library.valueOrNull == null
        ? const <int, WorkoutCategory>{}
        : <int, WorkoutCategory>{
            for (final WorkoutCategory category
                in library.valueOrNull!.categories)
              if (category.id != null) category.id!: category,
          };

    if (workouts.isEmpty) {
      return EmptyWidget(
        title: context.l10n.emptyNoResults,
        subtitle: context.l10n.emptyNoResultsSubtitle,
        icon: Icons.search_off_rounded,
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      itemCount: workouts.length,
      separatorBuilder: (BuildContext context, int index) =>
          AppSpacing.sm.heightSpace,
      itemBuilder: (BuildContext context, int index) {
        final Workout workout = workouts[index];
        return WorkoutCard(
          workout: workout,
          category: workout.categoryId == null
              ? null
              : categoriesById[workout.categoryId],
          onTap: () => context.push(
            AppRoutes.workoutDetailPath(workout.id!),
          ),
          onFavorite: () => toggleWorkoutFavorite(ref, workout.id!),
        );
      },
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ActionChip(
        onPressed: onTap,
        avatar: icon == null
            ? null
            : Icon(
                icon,
                size: 18,
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
        label: Text(label),
        backgroundColor: selected ? scheme.secondaryContainer : scheme.surface,
        side: BorderSide(
          color: selected
              ? Colors.transparent
              : scheme.outlineVariant,
        ),
        labelStyle: context.textTheme.labelMedium?.copyWith(
          color: selected
              ? scheme.onSecondaryContainer
              : scheme.onSurface,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _PickerOption<T> {
  const _PickerOption({
    required this.label,
    required this.value,
    required this.selected,
  });

  final String label;
  final T value;
  final bool selected;
}

class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({required this.title, required this.options});

  final String title;
  final List<_PickerOption<T>> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final _PickerOption<T> option in options)
              ListTile(
                onTap: () => Navigator.pop(context, option.value),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                selected: option.selected,
                selectedTileColor: context.colorScheme.secondaryContainer,
                leading: Icon(
                  option.selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: option.selected
                      ? context.colorScheme.primary
                      : context.colorScheme.onSurfaceVariant,
                ),
                title: Text(option.label),
              ),
          ],
        ),
      ),
    );
  }
}
