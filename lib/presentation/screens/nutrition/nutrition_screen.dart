import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/daily_nutrition.dart';
import '../../../domain/entities/meal_category.dart';
import '../../../domain/entities/meal_slot.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/nutrition_providers.dart';
import '../../router/app_router.dart';
import 'food_database_screen.dart';
import 'widgets/calorie_ring.dart';
import 'widgets/macro_goal_row.dart';
import 'widgets/meal_slot_card.dart';
import 'widgets/nutrition_date_format.dart';

/// Nutrition module home: the daily calorie/macro tracker, meal logging and
/// water integration for the selected date.
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(shellTabIndexProvider, (int? previous, int next) {
      if (next == 3 && previous != null && previous != 3) {
        ref.read(nutritionDailyControllerProvider.notifier).refresh();
      }
    });

    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final AsyncValue<DailyNutrition> async = ref.watch(
      nutritionDailyControllerProvider,
    );
    final AsyncValue<List<MealCategory>> categories = ref.watch(
      nutritionMealCategoriesProvider,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(nutritionDailyControllerProvider.notifier).refresh(),
          child: async.when(
            data: (DailyNutrition data) => _NutritionContent(
              data: data,
              categories: categories.valueOrNull ?? const <MealCategory>[],
            ),
            error: (Object error, StackTrace stackTrace) => _NutritionError(
              onRetry: () =>
                  ref.read(nutritionDailyControllerProvider.notifier).refresh(),
            ),
            loading: () => const _NutritionLoading(),
          ),
        ),
      ),
    );
  }
}

class _NutritionContent extends ConsumerWidget {
  const _NutritionContent({required this.data, required this.categories});

  final DailyNutrition data;
  final List<MealCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final DateTime selected = ref.watch(nutritionSelectedDateProvider);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          automaticallyImplyLeading: false,
          pinned: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          title: Text(
            l10n.tabNutrition,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => context.push(
                AppRoutes.foodDatabase,
                extra: const FoodDatabaseArgs.pick(),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: l10n.nutritionAddFood,
            ),
            IconButton(
              onPressed: () => context.push(AppRoutes.macroTracker),
              icon: const Icon(Icons.donut_large_rounded),
              tooltip: l10n.nutritionMacroTracker,
            ),
            IconButton(
              onPressed: () => context.push(AppRoutes.nutritionHistory),
              icon: const Icon(Icons.history_rounded),
              tooltip: l10n.nutritionHistory,
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
                    _DateNavigator(selected: selected),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryCard(data: data),
                    const SizedBox(height: AppSpacing.md),
                    _MacroGoalsCard(data: data),
                    const SizedBox(height: AppSpacing.md),
                    _WaterCard(data: data),
                    const SizedBox(height: AppSpacing.md),
                    const _DailyActions(),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.nutritionMeals,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (categories.isEmpty)
                      const SizedBox.shrink()
                    else
                      ...data.slots.map(
                        (MealSlot slot) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: MealSlotCard(
                            slot: slot,
                            defaultExpanded: slot.itemCount > 0,
                            onAddPressed: () => context.push(
                              AppRoutes.foodDatabase,
                              extra: const FoodDatabaseArgs.pick(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateNavigator extends ConsumerWidget {
  const _DateNavigator({required this.selected});

  final DateTime selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final DateTime today = DateTime.now();
    final DateTime todayStart = DateTime(today.year, today.month, today.day);
    final bool isToday = selected == todayStart;

    return Row(
      children: [
        IconButton.outlined(
          onPressed: () {
            ref.read(nutritionSelectedDateProvider.notifier).state =
                selected.subtract(const Duration(days: 1));
          },
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: l10n.commonBack,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                formatNutritionDate(selected, l10n),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isToday
                    ? l10n.commonToday
                    : '${selected.difference(todayStart).inDays.abs().toString().toBanglaDigits()} '
                          '${selected.isAfter(todayStart) ? l10n.nutritionDaysAgo : l10n.nutritionDaysLater}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton.outlined(
          onPressed: isToday
              ? null
              : () {
                  ref.read(nutritionSelectedDateProvider.notifier).state =
                      selected.add(const Duration(days: 1));
                },
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: l10n.commonNext,
        ),
      ],
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.data});

  final DailyNutrition data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppCard(
      child: Row(
        children: [
          CalorieRing(
            value: data.caloriesRatio,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.calories.round().toString().toBanglaDigits(),
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
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.nutritionRemaining,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.remainingCalories.round().toString().toBanglaDigits()} '
                  '${l10n.dashboardKcalUnit}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                _GoalChip(data: data),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({required this.data});

  final DailyNutrition data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Color color = data.isGoalMet
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;
    final String label = data.isGoalMet
        ? l10n.nutritionGoalMet
        : l10n.nutritionGoalProgress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            data.isGoalMet ? Icons.check_circle_rounded : Icons.track_changes_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroGoalsCard extends StatelessWidget {
  const _MacroGoalsCard({required this.data});

  final DailyNutrition data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.nutritionMacros,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          MacroGoalRow(
            label: l10n.nutritionProtein,
            color: Theme.of(context).colorScheme.primary,
            current: data.protein,
            target: data.targetProtein,
          ),
          const SizedBox(height: AppSpacing.md),
          MacroGoalRow(
            label: l10n.nutritionCarbs,
            color: Theme.of(context).colorScheme.secondary,
            current: data.carbs,
            target: data.targetCarbs,
          ),
          const SizedBox(height: AppSpacing.md),
          MacroGoalRow(
            label: l10n.nutritionFat,
            color: Theme.of(context).colorScheme.tertiary,
            current: data.fat,
            target: data.targetFat,
          ),
        ],
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.data});

  final DailyNutrition data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return AppCard(
      onPressed: () => context.push(AppRoutes.water),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.water_drop_rounded,
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.nutritionWaterIntake,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.nutritionWaterHint,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.waterMl.toString().toBanglaDigits()}'
                ' / ${data.targetWaterMl.toString().toBanglaDigits()} ${l10n.dashboardMlUnit}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 90,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: data.waterRatio,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.tertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyActions extends ConsumerWidget {
  const _DailyActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.mealPlanner),
                icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                label: Text(l10n.nutritionMealPlanner),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final int count = await _copyYesterdayCount(ref);
                  if (!context.mounted) return;
                  AppSnackbar.success(
                    context,
                    l10n.nutritionCopyYesterdayDone(
                      count.toString().toBanglaDigits(),
                    ),
                  );
                },
                icon: const Icon(Icons.content_copy_rounded, size: 18),
                label: Text(l10n.nutritionCopyYesterday),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: () => context.push(
            AppRoutes.foodDatabase,
            extra: const FoodDatabaseArgs.pick(),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(l10n.nutritionAddFood),
        ),
      ],
    );
  }

  Future<int> _copyYesterdayCount(WidgetRef ref) async {
    final int before =
        ref.read(nutritionDailyControllerProvider).value?.itemCount ?? 0;
    await copyYesterdayMeals(ref);
    final NutritionDailyController controller =
        ref.read(nutritionDailyControllerProvider.notifier);
    await controller.refresh();
    final int after =
        ref.read(nutritionDailyControllerProvider).value?.itemCount ?? 0;
    return (after - before).clamp(0, 999);
  }
}

class _NutritionLoading extends StatelessWidget {
  const _NutritionLoading();

  @override
  Widget build(BuildContext context) {
    return const LoadingWidget(message: null);
  }
}

class _NutritionError extends StatelessWidget {
  const _NutritionError({required this.onRetry});

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
