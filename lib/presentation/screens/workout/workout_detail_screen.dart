import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../core/widgets/layout/custom_app_bar.dart';
import '../../../domain/entities/workout_detail.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/workout_providers.dart';
import '../../router/app_router.dart';
import 'widgets/exercise_tile.dart';
import 'widgets/workout_card.dart';
import 'widgets/workout_cover.dart';

/// Full detail of a workout routine with a start action.
class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final int workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<WorkoutDetail> async = ref.watch(
      workoutDetailProvider(workoutId),
    );

    return Scaffold(
      body: SafeArea(
        child: async.when(
          data: (WorkoutDetail detail) => _DetailContent(detail: detail),
          error: (Object error, StackTrace stackTrace) => Column(
            children: [
              CustomAppBar(showBackButton: true),
              Expanded(
                child: ErrorWidget(
                  title: l10n.errorDatabase,
                  onRetry: () =>
                      ref.invalidate(workoutDetailProvider(workoutId)),
                ),
              ),
            ],
          ),
          loading: () => Column(
            children: const [
              CustomAppBar(showBackButton: true),
              Expanded(child: LoadingWidget()),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.detail});

  final WorkoutDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 220,
          leading: const Padding(
            padding: EdgeInsets.only(left: AppSpacing.xs),
            child: _RoundBackButton(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: _RoundIconButton(
                icon: detail.workout.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                onPressed: () => toggleWorkoutFavorite(ref, detail.workout.id!),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: WorkoutCover(
              colorValue: detail.category?.color,
              icon: categoryIconFor(detail.category?.icon),
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (detail.category != null)
                  Text(
                    detail.category!.name,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  detail.workout.name,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (detail.workout.difficulty != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DifficultyChip(
                      difficulty: detail.workout.difficulty!,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _StatTile(
                      icon: Icons.schedule_rounded,
                      value: workoutDurationLabel(
                        context,
                        detail.totalDurationMinutes,
                      ),
                    ),
                    _StatTile(
                      icon: Icons.local_fire_department_rounded,
                      value:
                          '${detail.estimatedCalories.round().toString().toBanglaDigits()} '
                          '${l10n.dashboardKcalUnit}',
                    ),
                    _StatTile(
                      icon: Icons.repeat_rounded,
                      value:
                          '${detail.exercises.length.toString().toBanglaDigits()} '
                          '${l10n.workoutExercises}',
                    ),
                  ],
                ),
                if (detail.workout.description != null &&
                    detail.workout.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.workoutAbout,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail.workout.description!,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (detail.targetMuscles.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.workoutMuscles,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ChipWrap(
                    items: detail.targetMuscles
                        .map((String muscle) => muscle.capitalize())
                        .toList(),
                  ),
                ],
                if (detail.equipment.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.workoutEquipment,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ChipWrap(items: detail.equipment),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.workoutRoutine,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${detail.exercises.length.toString().toBanglaDigits()} '
                      '${l10n.workoutExercises}',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                for (
                  int index = 0;
                  index < detail.exercises.length;
                  index++
                ) ...[
                  ExerciseTile(
                    detail: detail.exercises[index],
                    index: index,
                    onTap: () => context.push(
                      AppRoutes.exerciseDetailPath(
                        detail.exercises[index].exercise.id!,
                      ),
                    ),
                  ),
                  if (index < detail.exercises.length - 1)
                    AppSpacing.sm.heightSpace,
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  onPressed: () => context.push(
                    AppRoutes.workoutPlayer,
                    extra: WorkoutPlayerArgs(workoutId: detail.workout.id!),
                  ),
                  label: l10n.workoutStartNow,
                  icon: Icons.play_arrow_rounded,
                  size: AppButtonSize.large,
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colorScheme.surface.withValues(alpha: 0.85),
      ),
      child: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        tooltip: context.l10n.commonBack,
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colorScheme.surface.withValues(alpha: 0.85),
      ),
      child: IconButton(onPressed: onPressed, icon: Icon(icon)),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdRadius,
          color: context.colorScheme.surfaceContainerLow,
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: context.colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String item in items)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.pillRadius,
              border: Border.all(color: context.colorScheme.outlineVariant),
            ),
            child: Text(
              item,
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
