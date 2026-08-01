import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback/empty_widget.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/common_enums.dart';
import '../../../domain/entities/reminder_history.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/reminder_providers.dart';

/// Reminder history with Completed / Missed / Skipped filtering.
class ReminderHistoryScreen extends ConsumerWidget {
  const ReminderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ReminderHistory>> async = ref.watch(
      reminderHistoryControllerProvider,
    );
    final ReminderHistoryStatus? filter = ref.watch(
      reminderHistoryFilterProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.remindersHistory),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(reminderHistoryControllerProvider.notifier).refresh(),
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
          onRetry: () => ref.invalidate(reminderHistoryControllerProvider),
        ),
        data: (List<ReminderHistory> history) => _HistoryContent(
          history: history,
          filter: filter,
          onFilterChanged: (ReminderHistoryStatus? value) => ref
              .read(reminderHistoryFilterProvider.notifier)
              .state = value,
        ),
      ),
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent({
    required this.history,
    required this.filter,
    required this.onFilterChanged,
  });

  final List<ReminderHistory> history;
  final ReminderHistoryStatus? filter;
  final ValueChanged<ReminderHistoryStatus?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<ReminderHistory> visible = filter == null
        ? history
        : history.where((ReminderHistory h) => h.status == filter).toList();

    return Column(
      children: [
        _FilterChips(
          filter: filter,
          onChanged: onFilterChanged,
          counts: _counts(history),
        ),
        Expanded(
          child: visible.isEmpty
              ? EmptyWidget(
                  icon: Icons.history_rounded,
                  title: l10n.remindersHistoryEmpty,
                  subtitle: l10n.remindersHistoryEmptySubtitle,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.xxl,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (BuildContext context, int index) =>
                      _HistoryTile(entry: visible[index]),
                ),
        ),
      ],
    );
  }

  Map<ReminderHistoryStatus?, int> _counts(List<ReminderHistory> all) {
    return <ReminderHistoryStatus?, int>{
      null: all.length,
      ReminderHistoryStatus.completed: all
          .where(
            (ReminderHistory h) => h.status == ReminderHistoryStatus.completed,
          )
          .length,
      ReminderHistoryStatus.missed: all
          .where(
            (ReminderHistory h) => h.status == ReminderHistoryStatus.missed,
          )
          .length,
      ReminderHistoryStatus.skipped: all
          .where(
            (ReminderHistory h) => h.status == ReminderHistoryStatus.skipped,
          )
          .length,
    };
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.filter,
    required this.onChanged,
    required this.counts,
  });

  final ReminderHistoryStatus? filter;
  final ValueChanged<ReminderHistoryStatus?> onChanged;
  final Map<ReminderHistoryStatus?, int> counts;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<(ReminderHistoryStatus?, String)> options =
        <(ReminderHistoryStatus?, String)>[
          (null, l10n.remindersAll),
          (ReminderHistoryStatus.completed, l10n.remindersCompleted),
          (ReminderHistoryStatus.missed, l10n.remindersMissed),
          (ReminderHistoryStatus.skipped, l10n.remindersSkipped),
        ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: options.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(width: AppSpacing.xs),
          itemBuilder: (BuildContext context, int index) {
            final (ReminderHistoryStatus? value, String label) = options[index];
            final int count = counts[value] ?? 0;
            return FilterChip(
              label: Text('$label (${count.toString().toBanglaDigits()})'),
              selected: filter == value,
              onSelected: (bool selected) => onChanged(selected ? value : null),
            );
          },
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final ReminderHistory entry;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.isDarkMode ? AppColors.dark : AppColors.light;
    final (IconData, Color) style = switch (entry.status) {
      ReminderHistoryStatus.completed => (
        Icons.check_circle_rounded,
        colors.success,
      ),
      ReminderHistoryStatus.missed => (
        Icons.cancel_rounded,
        colors.danger,
      ),
      ReminderHistoryStatus.skipped => (
        Icons.skip_next_rounded,
        colors.warning,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: context.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(style.$1, color: style.$2),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(context.l10n, entry.status),
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy, h:mm a')
                      .format(entry.scheduledFor)
                      .toBanglaDigits(),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (entry.actedAt != null)
            Text(
              DateFormat('h:mm a').format(entry.actedAt!).toBanglaDigits(),
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, ReminderHistoryStatus status) {
    return switch (status) {
      ReminderHistoryStatus.completed => l10n.remindersCompleted,
      ReminderHistoryStatus.missed => l10n.remindersMissed,
      ReminderHistoryStatus.skipped => l10n.remindersSkipped,
    };
  }
}
