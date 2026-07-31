import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/empty_widget.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../core/widgets/layout/custom_app_bar.dart';
import '../../../domain/entities/workout_history.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/workout_providers.dart';
import '../../router/app_router.dart';

/// Completed workout sessions with lifetime totals.
class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<WorkoutHistoryData> async = ref.watch(
      workoutHistoryProvider,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(title: l10n.workoutHistory, showBackButton: true),
            Expanded(
              child: async.when(
                data: (WorkoutHistoryData data) {
                  if (data.sessions.isEmpty) {
                    return EmptyWidget(
                      title: l10n.workoutNoHistory,
                      subtitle: l10n.workoutNoHistorySubtitle,
                      icon: Icons.history_rounded,
                      actionLabel: l10n.commonRetry,
                      onActionPressed: () =>
                          ref.invalidate(workoutHistoryProvider),
                    );
                  }
                  return _HistoryBody(data: data);
                },
                error: (Object error, StackTrace stackTrace) => ErrorWidget(
                  title: l10n.errorDatabase,
                  onRetry: () => ref.invalidate(workoutHistoryProvider),
                ),
                loading: () => const LoadingWidget(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  const _HistoryBody({required this.data});

  final WorkoutHistoryData data;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        Row(
          children: [
            _SummaryTile(
              icon: Icons.fitness_center_rounded,
              value:
                  '${data.totalCompleted.toString().toBanglaDigits()} ${l10n.workoutTotalWorkouts}',
              label: l10n.workoutHistory,
            ),
            AppSpacing.sm.widthSpace,
            _SummaryTile(
              icon: Icons.local_fire_department_rounded,
              value:
                  '${data.totalCalories.round().toString().toBanglaDigits()} ${l10n.dashboardKcalUnit}',
              label: l10n.workoutCaloriesBurned,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (int index = 0; index < data.sessions.length; index++) ...[
          _SessionTile(
            history: data.sessions[index],
            name: data.workoutFor(data.sessions[index])?.name,
          ),
          if (index < data.sessions.length - 1) AppSpacing.sm.heightSpace,
        ],
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
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
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdRadius,
          color: context.colorScheme.surfaceContainerLow,
        ),
        child: Row(
          children: [
            Icon(icon, color: context.colorScheme.primary),
            AppSpacing.sm.widthSpace,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.history, this.name});

  final WorkoutHistory history;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DateTime endedAt = history.endedAt ?? history.startedAt;

    return AppCard(
      onPressed: () {
        final int? workoutId = history.workoutId;
        if (workoutId != null) {
          context.push(AppRoutes.workoutDetailPath(workoutId));
        }
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colorScheme.primaryContainer,
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              color: context.colorScheme.onPrimaryContainer,
            ),
          ),
          AppSpacing.md.widthSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? '${l10n.workoutExercise} #${history.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(endedAt),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.sm.widthSpace,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(history.durationMinutes ?? 0).toString().toBanglaDigits()} '
                '${l10n.dashboardMinutesShort}',
                style: context.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${(history.caloriesBurn ?? 0).round().toString().toBanglaDigits()} '
                '${l10n.dashboardKcalUnit}',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime day = DateTime(date.year, date.month, date.day);
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int difference = today.difference(day).inDays;

    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    final String time = '$hour:$minute';

    if (difference == 0 || difference == 1) return time;
    final String month = switch (date.month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      _ => 'Dec',
    };
    return '${date.day.toString().toBanglaDigits()} $month'
        '${date.year != now.year ? ' ${date.year.toString().toBanglaDigits()}' : ''}';
  }
}
