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
import '../../../domain/entities/exercise.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/exercise_providers.dart';
import '../../router/app_router.dart';
import '../workout/widgets/workout_card.dart';
import 'widgets/exercise_cover.dart';

/// Full detail of a single exercise with a start action.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Exercise?> async = ref.watch(
      exerciseDetailProvider(exerciseId),
    );

    return Scaffold(
      body: SafeArea(
        child: async.when(
          data: (Exercise? exercise) {
            if (exercise == null) {
              return Column(
                children: [
                  CustomAppBar(showBackButton: true),
                  Expanded(
                    child: ErrorWidget(
                      title: l10n.exerciseNoResults,
                      onRetry: () =>
                          ref.invalidate(exerciseDetailProvider(exerciseId)),
                    ),
                  ),
                ],
              );
            }
            return _DetailContent(exercise: exercise);
          },
          error: (Object error, StackTrace stackTrace) => Column(
            children: [
              CustomAppBar(showBackButton: true),
              Expanded(
                child: ErrorWidget(
                  title: l10n.errorDatabase,
                  onRetry: () =>
                      ref.invalidate(exerciseDetailProvider(exerciseId)),
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
  const _DetailContent({required this.exercise});

  final Exercise exercise;

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
                icon: exercise.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                onPressed: () {
                  final int? id = exercise.id;
                  if (id != null) toggleExerciseFavorite(ref, id);
                },
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: ExerciseCover(
              category: exercise.category,
              borderRadius: BorderRadius.zero,
              height: 220,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (exercise.category != null)
                  Text(
                    exercise.category!.name.capitalize(),
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  exercise.name,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (exercise.scientificName != null &&
                    exercise.scientificName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    exercise.scientificName!,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (exercise.difficulty != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DifficultyChip(
                      difficulty: exercise.difficulty!,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _StatTile(
                      icon: Icons.schedule_rounded,
                      value:
                          '${exercise.totalDurationSeconds.toString().toBanglaDigits()} '
                          '${l10n.workoutSeconds}',
                    ),
                    _StatTile(
                      icon: Icons.local_fire_department_rounded,
                      value:
                          '${exercise.totalEstimatedCalories.round().toString().toBanglaDigits()} '
                          '${l10n.dashboardKcalUnit}',
                    ),
                    _StatTile(
                      icon: Icons.repeat_rounded,
                      value:
                          '${exercise.sets.toString().toBanglaDigits()} × '
                          '${exercise.reps.toString().toBanglaDigits()}',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (exercise.bodyPart != null ||
                    exercise.secondaryMuscle != null) ...[
                  Text(
                    l10n.exerciseTargetMuscle,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      if (exercise.bodyPart != null)
                        _Chip(text: exercise.bodyPart!),
                      if (exercise.secondaryMuscle != null)
                        for (final String muscle in exercise.secondaryMuscle!
                            .split(','))
                          if (muscle.trim().isNotEmpty)
                            _Chip(text: muscle.trim()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (exercise.equipment != null &&
                    exercise.equipment!.isNotEmpty) ...[
                  Text(
                    l10n.workoutEquipment,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final String item in exercise.equipment!.split(','))
                        if (item.trim().isNotEmpty)
                          _Chip(text: item.trim().capitalize()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (exercise.description != null &&
                    exercise.description!.isNotEmpty) ...[
                  Text(
                    l10n.exerciseAbout,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    exercise.description!,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (exercise.instructions != null &&
                    exercise.instructions!.isNotEmpty) ...[
                  Text(
                    l10n.exerciseHowTo,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _InstructionList(instructions: exercise.instructions!),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (exercise.tips.isNotEmpty) ...[
                  _NoteSection(
                    title: l10n.exerciseTips,
                    icon: Icons.lightbulb_rounded,
                    color: context.colorScheme.tertiary,
                    items: exercise.tips,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (exercise.commonMistakes.isNotEmpty) ...[
                  _NoteSection(
                    title: l10n.exerciseCommonMistakes,
                    icon: Icons.error_outline_rounded,
                    color: context.colorScheme.error,
                    items: exercise.commonMistakes,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (exercise.safetyInstructions.isNotEmpty) ...[
                  _NoteSection(
                    title: l10n.exerciseSafety,
                    icon: Icons.health_and_safety_rounded,
                    color: context.colorScheme.secondary,
                    items: exercise.safetyInstructions,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  onPressed: () => context.push(
                    AppRoutes.exercisePlayer,
                    extra: ExercisePlayerArgs(exercise: exercise),
                  ),
                  label: l10n.exerciseStart,
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

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: context.colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _InstructionList extends StatelessWidget {
  const _InstructionList({required this.instructions});

  final String instructions;

  @override
  Widget build(BuildContext context) {
    final List<String> steps = instructions
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();

    return Column(
      children: <Widget>[
        for (int index = 0; index < steps.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colorScheme.primaryContainer,
                ),
                child: Text(
                  (index + 1).toString().toBanglaDigits(),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AppSpacing.sm.widthSpace,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    steps[index],
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (index < steps.length - 1)
            AppSpacing.sm.heightSpace,
        ],
      ],
    );
  }
}

class _NoteSection extends StatelessWidget {
  const _NoteSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdRadius,
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              AppSpacing.xs.widthSpace,
              Text(
                title,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final String item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                AppSpacing.sm.widthSpace,
                Expanded(
                  child: Text(
                    item,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (item != items.last) AppSpacing.xs.heightSpace,
          ],
        ],
      ),
    );
  }
}
