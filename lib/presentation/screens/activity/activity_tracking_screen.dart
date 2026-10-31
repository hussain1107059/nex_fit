import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/activity_metrics.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../data/services/location/location_service.dart';
import '../../../domain/entities/activity.dart';
import '../../../injection/dependency_injection.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/activity_providers.dart';
import '../../router/app_router.dart';
import 'widgets/activity_map.dart';
import 'widgets/activity_type_style.dart';

/// Arguments passed through `GoRouter` when starting a tracked activity.
class ActivityTrackingArgs {
  const ActivityTrackingArgs({required this.type, this.goal});

  final ActivityType type;
  final ActivityGoal? goal;
}

/// Live GPS tracking screen for [type].
class ActivityTrackingScreen extends ConsumerStatefulWidget {
  const ActivityTrackingScreen({super.key, required this.type, this.goal});

  final ActivityType type;
  final ActivityGoal? goal;

  @override
  ConsumerState<ActivityTrackingScreen> createState() =>
      _ActivityTrackingScreenState();
}

class _ActivityTrackingScreenState
    extends ConsumerState<ActivityTrackingScreen> {
  bool _allowPop = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(activityTrackingControllerProvider.notifier)
          .start(widget.type, goal: widget.goal);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ActivityTrackingState state = ref.watch(
      activityTrackingControllerProvider,
    );
    final ActivityTrackingController controller = ref.read(
      activityTrackingControllerProvider.notifier,
    );
    final bool active = state.isActive;

    return PopScope(
      canPop: _allowPop || !active,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(state.type.label(l10n)),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              if (active) {
                _confirmDiscard();
              } else {
                context.pop();
              }
            },
          ),
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: ActivityMap(
                      route: state.route,
                      current: state.route.isEmpty ? null : state.route.last,
                      live: true,
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    child: _StatusChip(state: state),
                  ),
                  if (state.goalAlertPlaying)
                    Positioned(
                      top: 54,
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      child: _GoalReachedBanner(
                        onStop: controller.stopGoalAlert,
                      ),
                    ),
                  if (state.failure != null)
                    Positioned.fill(
                      child: _FailureOverlay(
                        failure: state.failure!,
                        onRetry: () =>
                            state.status == ActivityTrackingStatus.paused
                            ? controller.resume()
                            : controller.start(widget.type, goal: widget.goal),
                        onOpenSettings: () => _openSettings(state.failure!),
                      ),
                    ),
                ],
              ),
            ),
            _MetricsPanel(
              state: state,
              finishing: _finishing,
              onStart: () => controller.start(widget.type, goal: widget.goal),
              onPause: controller.pause,
              onResume: controller.resume,
              onFinish: _finish,
              onDiscard: _confirmDiscard,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    final AppLocalizations l10n = context.l10n;
    setState(() => _finishing = true);
    final int? id = await ref
        .read(activityTrackingControllerProvider.notifier)
        .finish();
    if (!mounted) return;
    setState(() => _finishing = false);
    if (id != null) {
      AppSnackbar.success(context, l10n.activitySaved);
      context.pushReplacement(AppRoutes.activityDetailPath(id));
      return;
    }
    final ActivityTrackingState state = ref.read(
      activityTrackingControllerProvider,
    );
    if (state.saveFailed) {
      AppSnackbar.error(context, l10n.activitySaveFailed);
    } else {
      AppSnackbar.info(context, l10n.activityTooShort);
    }
  }

  Future<void> _openSettings(LocationFailure failure) async {
    final location = ref.read(locationServiceProvider);
    if (failure == LocationFailure.serviceDisabled) {
      await location.openLocationSettings();
    } else {
      await location.openAppSettings();
    }
  }

  Future<void> _confirmDiscard() async {
    final AppLocalizations l10n = context.l10n;
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.activityDiscardTitle),
        content: Text(l10n.activityDiscardMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.activityKeepGoing),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.activityDiscard),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    ref.read(activityTrackingControllerProvider.notifier).discard();
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final ActivityTrackingState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final (IconData icon, String label) = switch (state.status) {
      ActivityTrackingStatus.acquiring => (
        Icons.gps_fixed_rounded,
        l10n.activityAcquiring,
      ),
      ActivityTrackingStatus.tracking => (
        Icons.gps_fixed_rounded,
        l10n.activitySpeed,
      ),
      ActivityTrackingStatus.paused => (
        Icons.pause_circle_outline_rounded,
        l10n.activityPause,
      ),
      ActivityTrackingStatus.saving => (
        Icons.cloud_upload_outlined,
        l10n.commonSave,
      ),
      ActivityTrackingStatus.finished => (
        Icons.check_circle_outline_rounded,
        l10n.activitySaved,
      ),
      ActivityTrackingStatus.idle => (
        Icons.gps_not_fixed_rounded,
        l10n.activityStart,
      ),
    };

    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: context.colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: AppRadius.pillRadius,
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x1A000000), blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: context.colorScheme.primary),
            AppSpacing.xs.widthSpace,
            Text(
              state.status == ActivityTrackingStatus.tracking
                  ? '${ActivityMetrics.formatSpeedKmh(state.speedKmh).toBanglaDigits()} ${l10n.activityKmh}'
                  : label,
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Non-blocking banner shown while the target-reached chime is looping.
class _GoalReachedBanner extends StatelessWidget {
  const _GoalReachedBanner({required this.onStop});

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Material(
      color: context.colorScheme.primaryContainer,
      borderRadius: AppRadius.pillRadius,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.emoji_events_rounded,
              color: context.colorScheme.onPrimaryContainer,
              size: 20,
            ),
            AppSpacing.xs.widthSpace,
            Expanded(
              child: Text(
                l10n.activityTargetReached,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelLarge?.copyWith(
                  color: context.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.volume_off_rounded, size: 18),
              label: Text(l10n.activityTargetStopSound),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureOverlay extends StatelessWidget {
  const _FailureOverlay({
    required this.failure,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final LocationFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String message = switch (failure) {
      LocationFailure.serviceDisabled => l10n.activityServiceDisabled,
      LocationFailure.permissionDenied => l10n.activityPermissionDenied,
      LocationFailure.permissionPermanentlyDenied =>
        l10n.activityPermissionForever,
      LocationFailure.unavailable => l10n.activityLocationUnavailable,
    };
    final bool showSettings =
        failure == LocationFailure.serviceDisabled ||
        failure == LocationFailure.permissionPermanentlyDenied;

    return ColoredBox(
      color: context.colorScheme.surface.withValues(alpha: 0.9),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.location_off_rounded,
                  size: 40,
                  color: context.colorScheme.error,
                ),
                AppSpacing.sm.heightSpace,
                Text(
                  l10n.activityPermissionTitle,
                  textAlign: TextAlign.center,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppSpacing.xs.heightSpace,
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.md.heightSpace,
                if (showSettings) ...<Widget>[
                  AppButton(
                    label: l10n.activityOpenSettings,
                    icon: Icons.settings_rounded,
                    onPressed: onOpenSettings,
                  ),
                  AppSpacing.xs.heightSpace,
                ],
                AppButton(
                  label: l10n.commonRetry,
                  variant: AppButtonVariant.outline,
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel({
    required this.state,
    required this.finishing,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onDiscard,
  });

  final ActivityTrackingState state;
  final bool finishing;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = AppColors.light;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x22000000), blurRadius: 18),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.activityDistance,
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  ActivityMetrics.formatDistanceKm(
                    state.distanceMeters,
                  ).toBanglaDigits(),
                  style: context.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                AppSpacing.xs.widthSpace,
                Text(
                  l10n.activityKm,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (state.goal != null) ...<Widget>[
              AppSpacing.sm.heightSpace,
              _TargetProgress(state: state),
            ],
            if (state.stepSensorUnavailable) ...<Widget>[
              AppSpacing.xs.heightSpace,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.directions_walk_rounded,
                    size: 14,
                    color: context.colorScheme.error,
                  ),
                  AppSpacing.xxs.widthSpace,
                  Flexible(
                    child: Text(
                      l10n.activityStepsUnavailable,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            AppSpacing.sm.heightSpace,
            Row(
              children: <Widget>[
                _MetricCell(
                  label: l10n.activityDuration,
                  value: ActivityMetrics.formatDuration(
                    state.elapsedSeconds,
                  ).toBanglaDigits(),
                ),
                _MetricCell(
                  label: state.type.usesPace
                      ? l10n.activityPace
                      : l10n.activitySpeed,
                  value: state.type.usesPace
                      ? '${ActivityMetrics.formatPace(state.paceSecondsPerKm).toBanglaDigits()} ${l10n.activityMinPerKm}'
                      : '${ActivityMetrics.formatSpeedKmh(state.speedKmh).toBanglaDigits()} ${l10n.activityKmh}',
                ),
                _MetricCell(
                  label: l10n.activityCalories,
                  value: state.caloriesBurned
                      .round()
                      .toString()
                      .toBanglaDigits(),
                  color: colors.warning,
                ),
              ],
            ),
            AppSpacing.md.heightSpace,
            _Controls(
              status: state.status,
              finishing: finishing,
              onStart: onStart,
              onPause: onPause,
              onResume: onResume,
              onFinish: onFinish,
              onDiscard: onDiscard,
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetProgress extends StatelessWidget {
  const _TargetProgress({required this.state});

  final ActivityTrackingState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ActivityGoal goal = state.goal!;
    final String current = goal.isDistance
        ? ActivityMetrics.formatDistanceKm(state.distanceMeters)
        : state.steps.toString();
    final String target = goal.isDistance
        ? ActivityMetrics.formatDistanceKm(goal.value)
        : goal.targetSteps.toString();
    final String unit = goal.isDistance ? l10n.activityKm : l10n.activitySteps;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              l10n.activityTarget,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (state.goalReached) ...<Widget>[
              Icon(
                Icons.check_circle_rounded,
                size: 14,
                color: context.colorScheme.primary,
              ),
              AppSpacing.xxs.widthSpace,
            ],
            Text(
              '${current.toBanglaDigits()} / ${target.toBanglaDigits()} $unit',
              style: context.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: state.goalReached
                    ? context.colorScheme.primary
                    : context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        AppSpacing.xxs.heightSpace,
        ClipRRect(
          borderRadius: AppRadius.pillRadius,
          child: LinearProgressIndicator(
            value: state.goalProgress ?? 0,
            minHeight: 6,
            backgroundColor: context.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          AppSpacing.xxs.heightSpace,
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.status,
    required this.finishing,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onDiscard,
  });

  final ActivityTrackingStatus status;
  final bool finishing;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    if (status == ActivityTrackingStatus.acquiring ||
        status == ActivityTrackingStatus.saving) {
      return AppButton(
        label: status == ActivityTrackingStatus.acquiring
            ? l10n.activityAcquiring
            : l10n.commonSave,
        isLoading: true,
        onPressed: null,
      );
    }

    if (status == ActivityTrackingStatus.tracking) {
      return Row(
        children: <Widget>[
          Expanded(
            child: AppButton(
              label: l10n.activityPause,
              icon: Icons.pause_rounded,
              variant: AppButtonVariant.outline,
              onPressed: onPause,
            ),
          ),
          AppSpacing.sm.widthSpace,
          Expanded(
            child: AppButton(
              label: l10n.activityFinish,
              icon: Icons.stop_rounded,
              isLoading: finishing,
              onPressed: onFinish,
            ),
          ),
        ],
      );
    }

    if (status == ActivityTrackingStatus.paused) {
      return Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: l10n.activityResume,
                  icon: Icons.play_arrow_rounded,
                  onPressed: onResume,
                ),
              ),
              AppSpacing.sm.widthSpace,
              Expanded(
                child: AppButton(
                  label: l10n.activityFinish,
                  icon: Icons.stop_rounded,
                  variant: AppButtonVariant.outline,
                  isLoading: finishing,
                  onPressed: onFinish,
                ),
              ),
            ],
          ),
          TextButton(onPressed: onDiscard, child: Text(l10n.activityDiscard)),
        ],
      );
    }

    return AppButton(
      label: l10n.activityStart,
      icon: Icons.play_arrow_rounded,
      onPressed: onStart,
    );
  }
}
