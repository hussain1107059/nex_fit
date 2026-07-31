import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/workout.dart';
import '../../../domain/entities/workout_category.dart';
import '../../../domain/entities/workout_library.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/workout_providers.dart';
import '../../router/app_router.dart';
import 'widgets/continue_workout_card.dart';
import 'widgets/workout_card.dart';
import 'widgets/workout_cover.dart';

/// Workout module home: continue, categories, recommended, popular & recent.
class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen<int>(shellTabIndexProvider, (int? previous, int next) {
      if (next == 1 && previous != null && previous != 1) {
        ref.read(workoutLibraryControllerProvider.notifier).refresh();
      }
    });

    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final AsyncValue<WorkoutLibraryData> async = ref.watch(
      workoutLibraryControllerProvider,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(workoutLibraryControllerProvider.notifier).refresh(),
          child: async.when(
            data: (WorkoutLibraryData data) => _WorkoutContent(data: data),
            error: (Object error, StackTrace stackTrace) => _WorkoutError(
              onRetry: () =>
                  ref.read(workoutLibraryControllerProvider.notifier).refresh(),
            ),
            loading: () => const _WorkoutLoading(),
          ),
        ),
      ),
    );
  }
}

class _WorkoutContent extends StatelessWidget {
  const _WorkoutContent({required this.data});

  final WorkoutLibraryData data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool hasAnyWorkout = data.recommended.isNotEmpty;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          automaticallyImplyLeading: false,
          pinned: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          title: Text(
            l10n.tabWorkout,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => context.push(AppRoutes.workoutHistory),
              icon: const Icon(Icons.history_rounded),
              tooltip: l10n.workoutHistory,
            ),
            IconButton(
              onPressed: () => context.push(
                AppRoutes.workoutList,
                extra: const WorkoutListArgs.search(),
              ),
              icon: const Icon(Icons.search_rounded),
              tooltip: l10n.commonSearch,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchBar(),
                    if (data.continueWorkout != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      ContinueWorkoutCard(
                        continueWorkout: data.continueWorkout!,
                        onResume: () => context.push(
                          AppRoutes.workoutPlayer,
                          extra: WorkoutPlayerArgs(
                            workoutId: data.continueWorkout!.workout.id!,
                            historyId: data.continueWorkout!.historyId,
                            startedAt: data.continueWorkout!.startedAt,
                          ),
                        ),
                      ),
                    ],
                    if (data.categories.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _CategoryChips(categories: data.categories),
                    ],
                    if (!hasAnyWorkout) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _EmptyLibrary(
                        onBrowse: () => context.push(
                          AppRoutes.workoutList,
                          extra: const WorkoutListArgs.all(),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: AppSpacing.md),
                      _Section(
                        title: l10n.workoutRecommended,
                        onSeeAll: () => context.push(
                          AppRoutes.workoutList,
                          extra: const WorkoutListArgs.all(),
                        ),
                        child: _WorkoutRail(
                          workouts: data.recommended,
                          categoriesById: _categoryMap(data.categories),
                        ),
                      ),
                      if (data.popular.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _Section(
                          title: l10n.workoutPopular,
                          onSeeAll: () => context.push(
                            AppRoutes.workoutList,
                            extra: const WorkoutListArgs.all(),
                          ),
                          child: _WorkoutRail(
                            workouts: data.popular,
                            categoriesById: _categoryMap(data.categories),
                          ),
                        ),
                      ],
                      if (data.recent.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _Section(
                          title: l10n.workoutRecent,
                          onSeeAll: () => context.push(AppRoutes.workoutHistory),
                          child: _WorkoutRail(
                            workouts: data.recent,
                            categoriesById: _categoryMap(data.categories),
                          ),
                        ),
                      ],
                      if (data.favorites.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _Section(
                          title: l10n.workoutFavorites,
                          onSeeAll: () => context.push(
                            AppRoutes.workoutList,
                            extra: const WorkoutListArgs.favorites(),
                          ),
                          child: _WorkoutRail(
                            workouts: data.favorites,
                            categoriesById: _categoryMap(data.categories),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Map<int, WorkoutCategory> _categoryMap(List<WorkoutCategory> categories) {
    return <int, WorkoutCategory>{
      for (final WorkoutCategory category in categories)
        if (category.id != null) category.id!: category,
    };
  }
}

class _SearchBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onPressed: () => context.push(
        AppRoutes.workoutList,
        extra: const WorkoutListArgs.search(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: context.colorScheme.onSurfaceVariant,
          ),
          AppSpacing.sm.widthSpace,
          Expanded(
            child: Text(
              context.l10n.workoutSearchHint,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories});

  final List<WorkoutCategory> categories;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (BuildContext context, int index) =>
            AppSpacing.sm.widthSpace,
        itemBuilder: (BuildContext context, int index) {
          final WorkoutCategory category = categories[index];
          return _CategoryChip(category: category);
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final WorkoutCategory category;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: InkWell(
        borderRadius: AppRadius.mdRadius,
        onTap: () => context.push(
          AppRoutes.workoutList,
          extra: WorkoutListArgs.category(category.slug, category.name),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: AppRadius.mdRadius,
              child: SizedBox(
                width: 64,
                height: 64,
                child: WorkoutCover(
                  colorValue: category.color,
                  icon: categoryIconFor(category.icon),
                  borderRadius: AppRadius.mdRadius,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.onSeeAll,
    required this.child,
  });

  final String title;
  final VoidCallback onSeeAll;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: onSeeAll,
              child: Text(context.l10n.commonViewAll),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

class _WorkoutRail extends StatelessWidget {
  const _WorkoutRail({required this.workouts, required this.categoriesById});

  final List<Workout> workouts;
  final Map<int, WorkoutCategory> categoriesById;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 216,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: workouts.length,
        separatorBuilder: (BuildContext context, int index) =>
            AppSpacing.md.widthSpace,
        itemBuilder: (BuildContext context, int index) {
          final Workout workout = workouts[index];
          final WorkoutCategory? category =
              workout.categoryId == null ? null : categoriesById[workout.categoryId];
          return _VerticalWorkoutCard(workout: workout, category: category);
        },
      ),
    );
  }
}

class _VerticalWorkoutCard extends StatelessWidget {
  const _VerticalWorkoutCard({required this.workout, this.category});

  final Workout workout;
  final WorkoutCategory? category;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: AppCard(
        padding: EdgeInsets.zero,
        onPressed: () => context.push(
          AppRoutes.workoutDetailPath(workout.id!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
              child: WorkoutCover(
                colorValue: category?.color,
                icon: categoryIconFor(category?.icon),
                height: 96,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      workout.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${workoutDurationLabel(context, workout.durationMinutes)}'
                      ' · ${workout.caloriesBurn?.round() ?? 0} '
                      '${context.l10n.dashboardKcalUnit}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(
            Icons.fitness_center_rounded,
            size: 44,
            color: context.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.workoutEmptyTitle,
            style: context.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.workoutEmptySubtitle,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _WorkoutLoading extends StatelessWidget {
  const _WorkoutLoading();

  @override
  Widget build(BuildContext context) {
    return const LoadingWidget(message: null);
  }
}

class _WorkoutError extends StatelessWidget {
  const _WorkoutError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: ErrorWidget(
                title: context.l10n.errorDatabase,
                subtitle: context.l10n.errorDatabaseSubtitle,
                onRetry: onRetry,
              ),
            ),
          ],
        );
      },
    );
  }
}
