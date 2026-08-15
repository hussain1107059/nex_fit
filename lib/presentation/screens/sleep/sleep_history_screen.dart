import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/utils/sleep_stats.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/feedback/empty_widget.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/sleep_log.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/sleep_providers.dart';
import 'widgets/sleep_entry_sheet.dart';

/// Per-night sleep records with average stats, edit and delete.
class SleepHistoryScreen extends ConsumerWidget {
  const SleepHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SleepLog>> async = ref.watch(sleepHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.sleepHistory),
        actions: [
          IconButton(
            onPressed: () => showSleepEntrySheet(context, ref),
            icon: const Icon(Icons.add_rounded),
            tooltip: context.l10n.sleepHistoryAdd,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(sleepHistoryProvider),
        ),
        data: (List<SleepLog> logs) => _SleepHistoryContent(logs: logs),
      ),
    );
  }
}

class _SleepHistoryContent extends ConsumerWidget {
  const _SleepHistoryContent({required this.logs});

  final List<SleepLog> logs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SleepStats stats = SleepStats.from(logs);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        if (logs.isNotEmpty) ...[
          _StatsRow(stats: stats),
          const SizedBox(height: AppSpacing.md),
        ],
        if (logs.isEmpty)
          _EmptySleep(logs: logs)
        else
          AppCard(
            child: Column(
              children: [
                for (int i = 0; i < logs.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 64,
                      endIndent: AppSpacing.md,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  _SleepTile(log: logs[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final SleepStats stats;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = AppColors.light;
    return Row(
      children: [
        Expanded(
          child: _StatCell(
            label: context.l10n.sleepHistoryNights,
            value: stats.nights.toString().toBanglaDigits(),
            icon: Icons.nights_stay_rounded,
            color: colors.secondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCell(
            label: context.l10n.sleepHistoryAvgDuration,
            value: _formatDuration(context, stats.avgDurationMinutes.round()),
            icon: Icons.bedtime_rounded,
            color: context.colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCell(
            label: context.l10n.sleepHistoryAvgQuality,
            value: stats.avgQuality.toStringAsFixed(1).toBanglaDigits(),
            icon: Icons.star_rounded,
            color: colors.warning,
          ),
        ),
      ],
    );
  }

  String _formatDuration(BuildContext context, int minutes) {
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    final String h = context.l10n.dashboardSleepHour;
    final String m = context.l10n.dashboardSleepMinute;
    return '${'$hours$h'.toBanglaDigits()} ${'$rest$m'.toBanglaDigits()}';
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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

class _EmptySleep extends ConsumerWidget {
  const _EmptySleep({required this.logs});

  final List<SleepLog> logs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: EmptyWidget(
          icon: Icons.bedtime_rounded,
          title: context.l10n.sleepHistoryEmpty,
          subtitle: context.l10n.sleepHistoryEmptySubtitle,
          actionLabel: context.l10n.sleepHistoryAdd,
          onActionPressed: () => showSleepEntrySheet(context, ref),
        ),
      ),
    );
  }
}

class _SleepTile extends ConsumerWidget {
  const _SleepTile({required this.log});

  final SleepLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppColors colors = AppColors.light;
    final Color accent = colors.secondary;

    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.bedtime_rounded,
          size: 20,
          color: accent,
        ),
      ),
      title: Text(
        formatLocalizedDate(log.sleepDate, l10n),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatDuration(context, log.durationMinutes)} '
            '· ${_stars(context, log.quality)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (log.note != null && log.note!.isNotEmpty)
            Text(
              log.note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => showSleepEntrySheet(context, ref, existing: log),
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: l10n.sleepEditEntry,
          ),
          IconButton(
            onPressed: () async {
              await deleteSleepEntry(ref, log.id!);
              if (context.mounted) {
                AppSnackbar.success(context, l10n.sleepLogDeleted);
              }
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            tooltip: l10n.commonDelete,
          ),
        ],
      ),
    );
  }

  String _formatDuration(BuildContext context, int minutes) {
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    final String h = context.l10n.dashboardSleepHour;
    final String m = context.l10n.dashboardSleepMinute;
    return '${'$hours$h'.toBanglaDigits()} ${'$rest$m'.toBanglaDigits()}';
  }

  String _stars(BuildContext context, int quality) {
    return List<String>.filled(
      quality.clamp(0, 5),
      '★',
    ).join('').toBanglaDigits();
  }
}