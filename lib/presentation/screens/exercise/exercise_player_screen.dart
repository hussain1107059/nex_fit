import 'dart:async';

import 'package:flutter/material.dart' hide ErrorWidget;
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
import '../../../domain/entities/exercise.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/exercise_providers.dart';
import 'widgets/exercise_cover.dart';

/// Drives a single-exercise session with per-set countdown and rest phases.
class ExercisePlayerScreen extends ConsumerStatefulWidget {
  const ExercisePlayerScreen({super.key, required this.args});

  final ExercisePlayerArgs args;

  @override
  ConsumerState<ExercisePlayerScreen> createState() =>
      _ExercisePlayerScreenState();
}

class _ExercisePlayerScreenState extends ConsumerState<ExercisePlayerScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    ref
        .read(exercisePlayerControllerProvider.notifier)
        .start(widget.args.exercise);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final ExercisePlayerState? state = ref.read(
        exercisePlayerControllerProvider,
      );
      if (state == null || !state.isActive) {
        _timer?.cancel();
        return;
      }
      final ExercisePlayerPhase before = state.phase;
      ref.read(exercisePlayerControllerProvider.notifier).tick();
      final ExercisePlayerState? after = ref.read(
        exercisePlayerControllerProvider,
      );
      if (after != null &&
          after.phase == ExercisePlayerPhase.exercising &&
          before == ExercisePlayerPhase.resting) {
        _vibrate();
      }
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
    final ExercisePlayerState? state = ref.watch(
      exercisePlayerControllerProvider,
    );

    if (state == null) {
      return Scaffold(
        body: SafeArea(child: CustomAppBar(showBackButton: true)),
      );
    }

    if (state.phase == ExercisePlayerPhase.completed) {
      return ExerciseCompletionView(state: state);
    }

    final bool resting = state.phase == ExercisePlayerPhase.resting;

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
                title: state.exercise.name,
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
              Expanded(child: _buildSession(context, state, resting)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSession(
    BuildContext context,
    ExercisePlayerState state,
    bool resting,
  ) {
    final AppLocalizations l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.exerciseSetOf(
                    state.currentSet.toString().toBanglaDigits(),
                    state.totalSets.toString().toBanglaDigits(),
                  ),
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
              value: state.completionRatio,
              minHeight: 8,
              backgroundColor: context.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: Center(
              child: resting
                  ? _RestScreen(
                      exercise: state.exercise,
                      remaining: state.currentRemainingSeconds,
                      onSkip: () => ref
                          .read(exercisePlayerControllerProvider.notifier)
                          .skipRest(),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CountdownRing(
                          seconds: state.currentRemainingSeconds,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ClipRRect(
                          borderRadius: AppRadius.mdRadius,
                          child: SizedBox(
                            width: 120,
                            height: 120,
                            child: ExerciseCover(
                              category: state.exercise.category,
                              height: 120,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          state.exercise.name,
                          textAlign: TextAlign.center,
                          style: context.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (state.exercise.bodyPart != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            state.exercise.bodyPart!,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '${state.exercise.reps.toString().toBanglaDigits()} '
                          '${l10n.exerciseReps} · '
                          '${state.exercise.durationSeconds.toString().toBanglaDigits()} '
                          '${l10n.workoutSeconds}',
                          style: context.textTheme.labelLarge,
                        ),
                      ],
                    ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  onPressed: resting
                      ? () => ref
                          .read(exercisePlayerControllerProvider.notifier)
                          .skipRest()
                      : _confirmExit,
                  label: resting
                      ? l10n.workoutSkipRest
                      : l10n.workoutExit,
                  variant: AppButtonVariant.outline,
                ),
              ),
              AppSpacing.md.widthSpace,
              Expanded(
                child: AppButton(
                  onPressed: resting
                      ? () => ref
                          .read(exercisePlayerControllerProvider.notifier)
                          .skipRest()
                      : () => ref
                          .read(exercisePlayerControllerProvider.notifier)
                          .completeSet(),
                  label: resting
                      ? l10n.workoutEndRest
                      : state.isLastSet
                      ? l10n.workoutFinish
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

/// Full rest screen: countdown plus a preview of the next set.
class _RestScreen extends StatelessWidget {
  const _RestScreen({
    required this.exercise,
    required this.remaining,
    required this.onSkip,
  });

  final Exercise exercise;
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
        ClipRRect(
          borderRadius: AppRadius.mdRadius,
          child: SizedBox(
            width: 96,
            height: 96,
            child: ExerciseCover(
              category: exercise.category,
              height: 96,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          exercise.name,
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

/// Summary shown once the exercise session is finished.
class ExerciseCompletionView extends ConsumerWidget {
  const ExerciseCompletionView({super.key, required this.state});

  final ExercisePlayerState state;

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
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.colorScheme.primary.withValues(
                              alpha: 0.14,
                            ),
                          ),
                          child: Icon(
                            Icons.emoji_events_rounded,
                            size: 44,
                            color: context.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.exerciseCompleteTitle,
                          textAlign: TextAlign.center,
                          style: context.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.exerciseCompleteSubtitle,
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
                                  '${state.elapsedSeconds ~/ 60}${l10n.dashboardMinutesShort}',
                              label: l10n.exerciseDuration,
                            ),
                            _CompletionStat(
                              icon: Icons.local_fire_department_rounded,
                              value:
                                  '${state.caloriesBurned.round().toString().toBanglaDigits()} '
                                  '${l10n.dashboardKcalUnit}',
                              label: l10n.exerciseCaloriesEstimate,
                            ),
                            _CompletionStat(
                              icon: Icons.repeat_rounded,
                              value:
                                  '${state.completedSets.toString().toBanglaDigits()} '
                                  '${l10n.exerciseSets}',
                              label: l10n.exerciseSets,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          onPressed: () => context.pop(),
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
