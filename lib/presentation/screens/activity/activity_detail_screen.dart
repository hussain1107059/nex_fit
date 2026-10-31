import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/activity_metrics.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/feedback/empty_widget.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/activity.dart';
import '../../../injection/dependency_injection.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/activity_providers.dart';
import 'widgets/activity_map.dart';
import 'widgets/activity_type_style.dart';

/// Read-only summary of a saved activity session.
class ActivityDetailScreen extends ConsumerWidget {
  const ActivityDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<ActivitySession?> async = ref.watch(
      activitySessionProvider(sessionId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activityTitle),
        actions: <Widget>[
          async.maybeWhen(
            data: (ActivitySession? session) => session == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: l10n.commonDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _confirmDelete(context, ref),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        data: (ActivitySession? session) {
          if (session == null) {
            return EmptyWidget(
              icon: Icons.route_rounded,
              title: l10n.dashboardNoActivity,
            );
          }
          return _DetailContent(session: session);
        },
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: l10n.dashboardNoActivity,
          onRetry: () => ref.invalidate(activitySessionProvider(sessionId)),
        ),
        loading: () => const LoadingWidget(),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.activityDeleteTitle),
        content: Text(l10n.activityDeleteMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(activityRepositoryProvider).delete(sessionId);
      ref.invalidate(activityHistoryProvider);
      ref.invalidate(activityStatsProvider);
      if (!context.mounted) return;
      AppSnackbar.success(context, l10n.activityDeleted);
      context.pop();
    } on Exception {
      if (!context.mounted) return;
      AppSnackbar.error(context, l10n.activitySaveFailed);
    }
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.session});

  final ActivitySession session;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = AppColors.light;
    final Color accent = session.type.color(colors);
    final String started = DateFormat(
      'h:mm a',
    ).format(session.startedAt).toBanglaDigits();
    final String ended = session.endedAt == null
        ? '--'
        : DateFormat('h:mm a').format(session.endedAt!).toBanglaDigits();
    final ActivityGoal? goal = session.goal;
    final String? goalText = goal == null
        ? null
        : goal.isDistance
        ? '${ActivityMetrics.formatDistanceKm(goal.value).toBanglaDigits()} ${l10n.activityKm}'
        : '${goal.targetSteps.toString().toBanglaDigits()} ${l10n.activitySteps}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        ClipRRect(
          borderRadius: AppRadius.lgRadius,
          child: SizedBox(
            height: 260,
            child: session.route.isEmpty
                ? ColoredBox(
                    color: context.colorScheme.surfaceContainerHighest,
                    child: EmptyWidget(
                      icon: Icons.map_outlined,
                      title: l10n.activityNoRoute,
                    ),
                  )
                : ActivityMap(route: session.route),
          ),
        ),
        AppSpacing.md.heightSpace,
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: AppRadius.smRadius,
                ),
                child: Icon(session.type.icon, color: accent, size: 26),
              ),
              AppSpacing.sm.widthSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      session.type.label(l10n),
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppSpacing.xxs.heightSpace,
                    Text(
                      formatLocalizedDate(session.startedAt, l10n),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                ActivityMetrics.formatDistanceKm(
                  session.distanceMeters,
                ).toBanglaDigits(),
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              AppSpacing.xxs.widthSpace,
              Text(
                l10n.activityKm,
                style: context.textTheme.labelMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        AppSpacing.md.heightSpace,
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              _DetailMetric(
                icon: Icons.timer_outlined,
                label: l10n.activityDuration,
                value: ActivityMetrics.formatDuration(
                  session.durationSeconds,
                ).toBanglaDigits(),
              ),
              _DetailMetric(
                icon: Icons.speed_rounded,
                label: l10n.activityAvgSpeed,
                value:
                    '${ActivityMetrics.formatSpeedKmh(session.averageSpeedKmh).toBanglaDigits()} ${l10n.activityKmh}',
              ),
              _DetailMetric(
                icon: Icons.bolt_rounded,
                label: l10n.activityMaxSpeed,
                value:
                    '${ActivityMetrics.formatSpeedKmh(session.maxSpeedMps * 3.6).toBanglaDigits()} ${l10n.activityKmh}',
              ),
              _DetailMetric(
                icon: Icons.local_fire_department_rounded,
                label: l10n.activityCalories,
                value: session.caloriesBurned
                    .round()
                    .toString()
                    .toBanglaDigits(),
              ),
              _DetailMetric(
                icon: Icons.terrain_rounded,
                label: l10n.activityElevation,
                value:
                    '${session.elevationGainMeters.round().toString().toBanglaDigits()} ${l10n.activityMeters}',
              ),
              if (session.steps > 0)
                _DetailMetric(
                  icon: Icons.directions_walk_rounded,
                  label: l10n.activitySteps,
                  value: session.steps.toString().toBanglaDigits(),
                ),
              if (goalText != null)
                _DetailMetric(
                  icon: Icons.flag_rounded,
                  label: session.goalReached
                      ? l10n.activityTargetAchieved
                      : l10n.activityTarget,
                  value: goalText,
                ),
              _DetailMetric(
                icon: Icons.schedule_rounded,
                label: l10n.activityStarted,
                value: '$started - $ended',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: context.colorScheme.primary),
          AppSpacing.xs.widthSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
          ),
        ],
      ),
    );
  }
}
