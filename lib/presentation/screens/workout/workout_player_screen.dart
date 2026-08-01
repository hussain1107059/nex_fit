import 'dart:async';

import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/dialogs/app_dialog.dart';
import '../../../core/widgets/layout/custom_app_bar.dart';
import '../../../domain/entities/achievement.dart';
import '../../../domain/entities/badge.dart';
import '../../../domain/entities/workout_completion.dart';
import '../../../domain/entities/workout_exercise_detail.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/workout_providers.dart';
import '../../router/app_router.dart';

/// Drives a single workout session with a live countdown.
class WorkoutPlayerScreen extends ConsumerStatefulWidget {
  const WorkoutPlayerScreen({super.key, required this.args});

  final WorkoutPlayerArgs args;

  @override
  ConsumerState<WorkoutPlayerScreen> createState() =>
      _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends ConsumerState<WorkoutPlayerScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    ref.read(workoutPlayerControllerProvider.notifier).start(widget.args).then((
      _,
    ) {
      if (!mounted) return;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final WorkoutPlayerState? state = ref.read(
          workoutPlayerControllerProvider,
        );
        if (state == null || !state.isActive) {
          _timer?.cancel();
          return;
        }
        final WorkoutSessionPhase before = state.phase;
        ref.read(workoutPlayerControllerProvider.notifier).tick();
        final WorkoutPlayerState? after = ref.read(
          workoutPlayerControllerProvider,
        );
        if (after != null &&
            after.phase == WorkoutSessionPhase.exercising &&
            before == WorkoutSessionPhase.resting) {
          _vibrate();
        }
      });
    });
  }

  void _vibrate() {
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _confirmExit() async {
    final bool? leave = await AppDialog.confirm(
      context: context,
      title: context.l10n.workoutExitTitle,
      message: context.l10n.workoutExitMessage,
      confirmLabel: context.l10n.workoutExit,
      destructive: true,
    );
    if (leave == true && mounted) {
      _timer?.cancel();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final WorkoutPlayerState? state = ref.watch(
      workoutPlayerControllerProvider,
    );

    if (state == null) {
      return Scaffold(
        body: SafeArea(child: CustomAppBar(showBackButton: true)),
      );
    }

    if (state.phase == WorkoutSessionPhase.completed) {
      return WorkoutCompletionView(completion: state.completion!);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _confirmExit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              CustomAppBar(
                title: state.detail.workout.name,
                showBackButton: true,
                onBackPressed: _confirmExit,
                actions: [
                  IconButton(
                    onPressed: _confirmExit,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: context.l10n.workoutExit,
                  ),
                ],
              ),
              Expanded(child: _buildSession(context, state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSession(BuildContext context, WorkoutPlayerState state) {
    final AppLocalizations l10n = context.l10n;
    final WorkoutExerciseDetail? exercise = state.currentExercise;
    final double progress = state.totalExercises == 0
        ? 0
        : (state.currentIndex / state.totalExercises).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.workoutExercise} '
                  '${(state.currentIndex + 1).toString().toBanglaDigits()} / '
                  '${state.totalExercises.toString().toBanglaDigits()}',
                  style: context.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatElapsed(state.elapsedSeconds),
                style: context.textTheme.labelLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.pillRadius,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: context.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: Center(
              child: exercise == null
                  ? Text(l10n.workoutFinish)
                  : state.phase == WorkoutSessionPhase.resting
                  ? _WorkoutRestScreen(
                      currentIndex: state.currentIndex,
                      totalExercises: state.totalExercises,
                      nextExercise: exercise,
                      remaining: state.currentRemainingSeconds,
                      onSkip: () => ref
                          .read(workoutPlayerControllerProvider.notifier)
                          .skipExercise(),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CountdownRing(
                          seconds: state.currentRemainingSeconds,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          exercise.exercise.name,
                          textAlign: TextAlign.center,
                          style: context.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (exercise.exercise.bodyPart != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            exercise.exercise.bodyPart!,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '${exercise.sets.toString().toBanglaDigits()} ${l10n.workoutSets} · '
                          '${exercise.reps > 0 ? '${exercise.reps.toString().toBanglaDigits()} ${l10n.workoutReps}' : '${exercise.durationSeconds.toString().toBanglaDigits()} ${l10n.workoutSeconds}'}',
                          style: context.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${exercise.restSeconds.toString().toBanglaDigits()} ${l10n.workoutRest}',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  onPressed: () => ref
                      .read(workoutPlayerControllerProvider.notifier)
                      .skipExercise(),
                  label: state.phase == WorkoutSessionPhase.resting
                      ? l10n.workoutSkipRest
                      : l10n.commonSkip,
                  variant: AppButtonVariant.outline,
                ),
              ),
              AppSpacing.md.widthSpace,
              Expanded(
                child: AppButton(
                  onPressed: () => ref
                      .read(workoutPlayerControllerProvider.notifier)
                      .completeCurrentExercise(),
                  label: state.phase == WorkoutSessionPhase.resting
                      ? l10n.workoutEndRest
                      : l10n.workoutComplete,
                  icon: Icons.check_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatElapsed(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final Color color = context.colorScheme.primary;
    final int displayed = seconds.clamp(0, 1 << 20);

    return Container(
      width: 176,
      height: 176,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 2),
      ),
      child: Center(
        child: Text(
          displayed.toString().toBanglaDigits(),
          style: context.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Full rest screen shown between exercises inside a workout.
class _WorkoutRestScreen extends StatelessWidget {
  const _WorkoutRestScreen({
    required this.currentIndex,
    required this.totalExercises,
    required this.nextExercise,
    required this.remaining,
    required this.onSkip,
  });

  final int currentIndex;
  final int totalExercises;
  final WorkoutExerciseDetail nextExercise;
  final int remaining;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillRadius,
            color: context.colorScheme.tertiaryContainer,
          ),
          child: Text(
            l10n.workoutRestTitle,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          remaining.toString().toBanglaDigits(),
          style: context.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.colorScheme.tertiary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${l10n.exerciseNextUp} ${(currentIndex + 1).toString().toBanglaDigits()} / ${totalExercises.toString().toBanglaDigits()}',
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          nextExercise.exercise.name,
          textAlign: TextAlign.center,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton.icon(
          onPressed: onSkip,
          icon: const Icon(Icons.fast_forward_rounded),
          label: Text(l10n.workoutSkipRest),
        ),
      ],
    );
  }
}

/// Summary shown once the session is finished.
class WorkoutCompletionView extends ConsumerWidget {
  const WorkoutCompletionView({super.key, required this.completion});

  final WorkoutCompletion completion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        const SizedBox(height: AppSpacing.lg),
                        _CompletionBadge(
                          icon: Icons.emoji_events_rounded,
                          color: context.colorScheme.primary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (completion.workoutName != null) ...[
                          Text(
                            completion.workoutName!,
                            textAlign: TextAlign.center,
                            style: context.textTheme.titleMedium?.copyWith(
                              color: context.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          l10n.workoutSummary,
                          textAlign: TextAlign.center,
                          style: context.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.workoutSummaryMotivation,
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            _CompletionStat(
                              icon: Icons.schedule_rounded,
                              value:
                                  '${completion.durationMinutes.toString().toBanglaDigits()} '
                                  '${l10n.dashboardMinutesShort}',
                              label: l10n.workoutDuration,
                            ),
                            _CompletionStat(
                              icon: Icons.local_fire_department_rounded,
                              value:
                                  '${completion.caloriesBurned.round().toString().toBanglaDigits()} '
                                  '${l10n.dashboardKcalUnit}',
                              label: l10n.workoutCaloriesBurned,
                            ),
                            _CompletionStat(
                              icon: Icons.check_circle_rounded,
                              value:
                                  '${completion.completionPercent.round().toString().toBanglaDigits()}%',
                              label: l10n.workoutSummaryCompletion,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            _CompletionStat(
                              icon: Icons.repeat_rounded,
                              value:
                                  '${completion.exercisesCompleted.toString().toBanglaDigits()} / '
                                  '${completion.totalExercises.toString().toBanglaDigits()}',
                              label: l10n.workoutExercises,
                            ),
                            _CompletionStat(
                              icon: Icons.local_fire_department_rounded,
                              value:
                                  '${completion.currentStreak.toString().toBanglaDigits()} '
                                  '${l10n.workoutSummaryDays}',
                              label: l10n.workoutSummaryStreak,
                            ),
                            const _EmptyStat(),
                          ],
                        ),
                        if (completion.newBadges.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            l10n.workoutSummaryBadges,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final Badge badge in completion.newBadges) ...[
                            _BadgeTile(badge: badge),
                            AppSpacing.sm.heightSpace,
                          ],
                        ],
                        if (completion.newAchievements.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            l10n.workoutNewAchievements,
                            style: context.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          for (final Achievement achievement
                              in completion.newAchievements) ...[
                            _AchievementTile(achievement: achievement),
                            AppSpacing.sm.heightSpace,
                          ],
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          onPressed: () => context.go(AppRoutes.shell),
                          label: l10n.workoutDone,
                          icon: Icons.check_circle_rounded,
                          size: AppButtonSize.large,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionBadge extends StatelessWidget {
  const _CompletionBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
      ),
      child: Icon(icon, size: 44, color: color),
    );
  }
}

class _CompletionStat extends StatelessWidget {
  const _CompletionStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: context.colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder used to balance a stats row without content.
class _EmptyStat extends StatelessWidget {
  const _EmptyStat();

  @override
  Widget build(BuildContext context) {
    return const Expanded(child: SizedBox.shrink());
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final Badge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdRadius,
        color: context.colorScheme.tertiaryContainer.withValues(alpha: 0.6),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colorScheme.tertiary.withValues(alpha: 0.18),
            ),
            child: Icon(
              Icons.military_tech_rounded,
              color: context.colorScheme.tertiary,
            ),
          ),
          AppSpacing.md.widthSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.badgeName,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: AppRadius.pillRadius,
                  child: LinearProgressIndicator(
                    value: badge.target > 0
                        ? (badge.progress / badge.target).clamp(0.0, 1.0)
                        : 0,
                    minHeight: 6,
                    backgroundColor: context.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdRadius,
        color: context.colorScheme.secondaryContainer.withValues(alpha: 0.6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events_rounded,
            color: context.colorScheme.secondary,
          ),
          AppSpacing.md.widthSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.name,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (achievement.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    achievement.description!,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
