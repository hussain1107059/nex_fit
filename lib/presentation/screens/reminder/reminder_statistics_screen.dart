import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/reminder.dart';
import '../../../domain/entities/reminder_statistics.dart';
import '../../providers/reminder_providers.dart';
import 'reminder_ui.dart';

/// Reminder statistics: completion rate, missed rate and the most successful
/// reminder.
class ReminderStatisticsScreen extends ConsumerWidget {
  const ReminderStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ReminderStatistics> async = ref.watch(
      reminderStatisticsProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.remindersStatistics),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(reminderStatisticsProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.commonRetry,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(reminderStatisticsProvider),
        ),
        data: (ReminderStatistics stats) => _StatisticsContent(stats: stats),
      ),
    );
  }
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({required this.stats});

  final ReminderStatistics stats;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.light;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        Row(
          children: [
            _RateCard(
              label: context.l10n.remindersCompletionRate,
              value: stats.completionRate,
              color: colors.success,
              icon: Icons.task_alt_rounded,
            ),
            const SizedBox(width: AppSpacing.sm),
            _RateCard(
              label: context.l10n.remindersMissedRate,
              value: stats.missedRate,
              color: colors.danger,
              icon: Icons.event_busy_rounded,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _CountCard(
              label: context.l10n.remindersCompleted,
              count: stats.completed,
              color: colors.success,
            ),
            const SizedBox(width: AppSpacing.sm),
            _CountCard(
              label: context.l10n.remindersMissed,
              count: stats.missed,
              color: colors.danger,
            ),
            const SizedBox(width: AppSpacing.sm),
            _CountCard(
              label: context.l10n.remindersSkipped,
              count: stats.skipped,
              color: colors.warning,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _MostSuccessfulCard(stats: stats),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '${context.l10n.remindersTotal} ${stats.total.toString().toBanglaDigits()}',
          textAlign: TextAlign.center,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final int rounded = value.round();
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: AppRadius.lgRadius,
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${rounded.toString().toBanglaDigits()}%',
              style: context.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: AppRadius.mdRadius,
          border: Border.all(color: context.colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Text(
              count.toString().toBanglaDigits(),
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
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

class _MostSuccessfulCard extends StatelessWidget {
  const _MostSuccessfulCard({required this.stats});

  final ReminderStatistics stats;

  @override
  Widget build(BuildContext context) {
    final Reminder? reminder = stats.mostSuccessfulReminder;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colorScheme.primaryContainer.withValues(alpha: 0.55),
            context.colorScheme.secondaryContainer.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(
          color: context.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          if (reminder != null)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: reminderTypeColor(reminder.reminderType)
                    .withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                reminderTypeIcon(reminder.reminderType),
                color: reminderTypeColor(reminder.reminderType),
              ),
            )
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.remindersMostSuccessful,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  reminder?.title ?? context.l10n.remindersNoData,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (reminder != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    context.l10n.remindersCompletedCount(
                      stats.mostSuccessfulCompleted.toString().toBanglaDigits(),
                    ),
                    style: context.textTheme.bodySmall?.copyWith(
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
