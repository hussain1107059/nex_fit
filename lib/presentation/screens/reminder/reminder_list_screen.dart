import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/feedback/empty_widget.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/common_enums.dart';
import '../../../domain/entities/reminder.dart';
import '../../../domain/entities/smart_reminder_suggestion.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/reminder_providers.dart';
import '../../router/app_router.dart';
import 'reminder_ui.dart';

/// Reminder centre: all reminders with smart suggestions, today / upcoming
/// views and full CRUD.
class ReminderListScreen extends ConsumerStatefulWidget {
  const ReminderListScreen({super.key});

  @override
  ConsumerState<ReminderListScreen> createState() => _ReminderListScreenState();
}

enum _ReminderFilter { all, today, upcoming }

class _ReminderListScreenState extends ConsumerState<ReminderListScreen> {
  _ReminderFilter _filter = _ReminderFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(reminderListControllerProvider.notifier).refresh();
      syncMissedReminders(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Reminder>> async = ref.watch(
      reminderListControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.remindersTitle),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.reminderSettings),
            icon: const Icon(Icons.tune_rounded),
            tooltip: context.l10n.remindersSettings,
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.reminderStatistics),
            icon: const Icon(Icons.insights_rounded),
            tooltip: context.l10n.remindersStatistics,
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.reminderHistory),
            icon: const Icon(Icons.history_rounded),
            tooltip: context.l10n.remindersHistory,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.reminderEditor),
        icon: const Icon(Icons.add_alert_rounded),
        label: Text(context.l10n.remindersAdd),
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(reminderListControllerProvider),
        ),
        data: (List<Reminder> reminders) => _RemindersContent(
          reminders: reminders,
          filter: _filter,
          onFilterChanged: (_ReminderFilter value) {
            setState(() => _filter = value);
          },
        ),
      ),
    );
  }
}

class _RemindersContent extends ConsumerWidget {
  const _RemindersContent({
    required this.reminders,
    required this.filter,
    required this.onFilterChanged,
  });

  final List<Reminder> reminders;
  final _ReminderFilter filter;
  final ValueChanged<_ReminderFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = DateTime.now();
    final ReminderTimeFormat timeFormat = ref.watch(reminderSettingsProvider).timeFormat;

    final List<Reminder> todays = remindersOnDate(reminders, now);
    final List<({Reminder reminder, DateTime at})> upcoming = upcomingReminders(
      reminders,
      now,
    );

    final List<Reminder> visible = switch (filter) {
      _ReminderFilter.all => reminders,
      _ReminderFilter.today => todays,
      _ReminderFilter.upcoming =>
        upcoming.map((entry) => entry.reminder).toList(),
    };

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(reminderListControllerProvider.notifier).refresh();
        await syncMissedReminders(ref);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          _SummaryRow(reminders: reminders, todays: todays.length, upcoming: upcoming.length),
          const SizedBox(height: AppSpacing.md),
          const _SmartSuggestionsCard(),
          const SizedBox(height: AppSpacing.md),
          _FilterTabs(
            filter: filter,
            onChanged: onFilterChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (visible.isEmpty)
            _EmptyReminders(filter: filter)
          else
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                children: [
                  for (int i = 0; i < visible.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 64,
                        endIndent: AppSpacing.md,
                        color: context.colorScheme.outlineVariant,
                      ),
                    _ReminderTile(reminder: visible[i], timeFormat: timeFormat),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.reminders,
    required this.todays,
    required this.upcoming,
  });

  final List<Reminder> reminders;
  final int todays;
  final int upcoming;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Row(
      children: [
        _SummaryChip(
          icon: Icons.notifications_active_rounded,
          label: l10n.remindersCount('${reminders.length}'),
          color: context.colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.xs),
        _SummaryChip(
          icon: Icons.today_rounded,
          label: l10n.remindersToday('$todays'),
          color: context.colorScheme.secondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        _SummaryChip(
          icon: Icons.upcoming_rounded,
          label: l10n.remindersUpcoming('$upcoming'),
          color: context.colorScheme.tertiary,
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: AppRadius.mdRadius,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.filter, required this.onChanged});

  final _ReminderFilter filter;
  final ValueChanged<_ReminderFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<(_ReminderFilter, String)> options = <(_ReminderFilter, String)>[
      (_ReminderFilter.all, l10n.remindersAll),
      (_ReminderFilter.today, l10n.remindersTodayLabel),
      (_ReminderFilter.upcoming, l10n.remindersUpcomingLabel),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Row(
        children: [
          for (final (_ReminderFilter value, String label) in options)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(value),
                borderRadius: AppRadius.pillRadius,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: filter == value
                        ? context.colorScheme.surface
                        : Colors.transparent,
                    borderRadius: AppRadius.pillRadius,
                    boxShadow: filter == value
                        ? <BoxShadow>[
                            BoxShadow(
                              color: context.colorScheme.shadow.withValues(
                                alpha: 0.06,
                              ),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: context.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: filter == value
                          ? context.colorScheme.primary
                          : context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SmartSuggestionsCard extends ConsumerWidget {
  const _SmartSuggestionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SmartReminderSuggestion>> async = ref.watch(
      smartReminderSuggestionsProvider,
    );
    final List<SmartReminderSuggestion>? suggestions = async.valueOrNull;
    if (suggestions == null || suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colorScheme.primaryContainer.withValues(alpha: 0.55),
            context.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(
          color: context.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                context.l10n.remindersSmartSuggestions,
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final SmartReminderSuggestion suggestion in suggestions) ...[
            _SuggestionRow(suggestion: suggestion),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _SuggestionRow extends ConsumerWidget {
  const _SuggestionRow({required this.suggestion});

  final SmartReminderSuggestion suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color color = reminderTypeColor(suggestion.type);

    return InkWell(
      onTap: () {
        final String? route = suggestion.relatedScreen;
        if (route != null) {
          context.push(route);
        }
      },
      borderRadius: AppRadius.mdRadius,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(reminderTypeIcon(suggestion.type), size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.title,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  suggestion.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          TextButton(
            onPressed: () => context.push(AppRoutes.reminderEditor),
            child: Text(context.l10n.remindersAdd),
          ),
        ],
      ),
    );
  }
}

class _EmptyReminders extends StatelessWidget {
  const _EmptyReminders({required this.filter});

  final _ReminderFilter filter;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: EmptyWidget(
          icon: Icons.notifications_none_rounded,
          title: context.l10n.remindersEmpty,
          subtitle: context.l10n.remindersEmptySubtitle,
        ),
      ),
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.reminder, required this.timeFormat});

  final Reminder reminder;
  final ReminderTimeFormat timeFormat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final Color color = reminderTypeColor(reminder.reminderType);
    final Color titleColor = reminder.isEnabled
        ? context.colorScheme.onSurface
        : context.colorScheme.onSurfaceVariant;

    return ListTile(
      onTap: () => context.push(
        AppRoutes.reminderEditor,
        extra: reminder,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(
            alpha: reminder.isEnabled ? 0.16 : 0.08,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          reminderTypeIcon(reminder.reminderType),
          size: 20,
          color: reminder.isEnabled ? color : context.colorScheme.outline,
        ),
      ),
      title: Text(
        reminder.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        reminderScheduleSummary(
          l10n,
          reminder,
          timeFormat: timeFormat,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodySmall?.copyWith(
          color: reminder.isEnabled
              ? context.colorScheme.onSurfaceVariant
              : context.colorScheme.outline,
        ),
      ),
      isThreeLine: reminder.body?.isNotEmpty ?? false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: reminder.isEnabled,
            onChanged: (bool enabled) =>
                toggleReminder(ref, reminder, enabled),
          ),
          PopupMenuButton<String>(
            onSelected: (String action) => _handleAction(
              context,
              ref,
              reminder,
              action,
            ),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'edit',
                child: Text(l10n.commonEdit),
              ),
              PopupMenuItem<String>(
                value: 'complete',
                child: Text(l10n.remindersComplete),
              ),
              PopupMenuItem<String>(
                value: 'skip',
                child: Text(l10n.remindersSkip),
              ),
              PopupMenuItem<String>(
                value: 'duplicate',
                child: Text(l10n.remindersDuplicate),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(
                  l10n.commonDelete,
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    Reminder reminder,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        context.push(AppRoutes.reminderEditor, extra: reminder);
      case 'complete':
        await recordReminderAction(
          ref,
          reminder.id!,
          ReminderHistoryStatus.completed,
        );
        if (context.mounted) {
          AppSnackbar.success(context, context.l10n.remindersMarkedComplete);
        }
      case 'skip':
        await recordReminderAction(
          ref,
          reminder.id!,
          ReminderHistoryStatus.skipped,
        );
        if (context.mounted) {
          AppSnackbar.info(context, context.l10n.remindersMarkedSkipped);
        }
      case 'duplicate':
        await duplicateReminder(ref, reminder.id!);
        if (context.mounted) {
          AppSnackbar.success(context, context.l10n.remindersDuplicated);
        }
      case 'delete':
        await deleteReminder(ref, reminder.id!);
        if (context.mounted) {
          AppSnackbar.success(context, context.l10n.remindersDeleted);
        }
    }
  }
}
