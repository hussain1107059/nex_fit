import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/feedback/empty_widget.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/reminder.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/water_providers.dart';

/// Hydration reminder management: presets + custom, all backed by local
/// notifications.
class WaterRemindersScreen extends ConsumerWidget {
  const WaterRemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Reminder>> async = ref.watch(waterRemindersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.waterReminders),
        actions: [
          IconButton(
            onPressed: () => _openEditor(context, ref),
            icon: const Icon(Icons.add_rounded),
            tooltip: context.l10n.waterReminderAddTitle,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(waterRemindersProvider),
        ),
        data: (List<Reminder> reminders) => _RemindersContent(
          reminders: reminders,
          onEdit: (Reminder reminder) =>
              _openEditor(context, ref, existing: reminder),
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref,
      {Reminder? existing}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReminderEditorSheet(existing: existing),
    );
  }
}

class _RemindersContent extends ConsumerWidget {
  const _RemindersContent({required this.reminders, required this.onEdit});

  final List<Reminder> reminders;
  final ValueChanged<Reminder> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          l10n.waterReminderDaysHint,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _PresetTile(
                icon: Icons.wb_twilight_rounded,
                label: l10n.waterReminderMorning,
                color: theme.colorScheme.tertiary,
                onTap: () => _applyPreset(ref, context, '08:00'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _PresetTile(
                icon: Icons.wb_sunny_rounded,
                label: l10n.waterReminderAfternoon,
                color: theme.colorScheme.secondary,
                onTap: () => _applyPreset(ref, context, '13:00'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _PresetTile(
                icon: Icons.nights_stay_rounded,
                label: l10n.waterReminderEvening,
                color: theme.colorScheme.primary,
                onTap: () => _applyPreset(ref, context, '20:00'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          '${l10n.waterReminders} '
          '(${reminders.length.toString().toBanglaDigits()})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (reminders.isEmpty)
          _EmptyReminders()
        else
          AppCard(
            child: Column(
              children: [
                for (int i = 0; i < reminders.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 64,
                      endIndent: AppSpacing.md,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  _ReminderTile(reminder: reminders[i], onEdit: onEdit),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _applyPreset(WidgetRef ref, BuildContext context, String time) async {
    final AppLocalizations l10n = context.l10n;
    final Reminder? existing = reminders
        .where((Reminder r) => r.time == time)
        .firstOrNull;
    try {
      if (existing != null) {
        await toggleWaterReminder(ref, existing, true);
      } else {
        await createWaterReminder(
          ref,
          title: l10n.waterReminderNotificationTitle,
          body: l10n.waterReminderNotificationBody,
          time: time,
        );
      }
      if (context.mounted) {
        AppSnackbar.success(context, l10n.waterReminderSaved);
      }
    } on Exception {
      if (context.mounted) {
        AppSnackbar.error(context, l10n.commonError);
      }
    }
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: AppRadius.lgRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgRadius,
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyReminders extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: EmptyWidget(
          icon: Icons.notifications_none_rounded,
          title: context.l10n.waterReminderNoReminders,
          subtitle: context.l10n.waterReminderNoRemindersSubtitle,
        ),
      ),
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.reminder, required this.onEdit});

  final Reminder reminder;
  final ValueChanged<Reminder> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Color accent = theme.colorScheme.tertiary;

    return ListTile(
      onTap: () => onEdit(reminder),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: accent.withValues(
            alpha: reminder.isEnabled ? 0.16 : 0.08,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.notifications_active_rounded,
          size: 20,
          color: reminder.isEnabled ? accent : theme.colorScheme.outline,
        ),
      ),
      title: Text(
        reminder.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: reminder.isEnabled
              ? null
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        _subtitle(l10n, reminder),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(reminder.time),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Switch(
            value: reminder.isEnabled,
            onChanged: (bool enabled) =>
                toggleWaterReminder(ref, reminder, enabled),
          ),
          IconButton(
            onPressed: () async {
              await deleteWaterReminder(ref, reminder.id!);
              if (context.mounted) {
                AppSnackbar.success(context, l10n.waterReminderDeleted);
              }
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            tooltip: l10n.commonDelete,
          ),
        ],
      ),
    );
  }

  String _subtitle(AppLocalizations l10n, Reminder reminder) {
    if (reminder.daysOfWeek.isEmpty) return l10n.waterReminderDaily;
    final List<String> names = <String>[
      l10n.waterWeekdayMonday,
      l10n.waterWeekdayTuesday,
      l10n.waterWeekdayWednesday,
      l10n.waterWeekdayThursday,
      l10n.waterWeekdayFriday,
      l10n.waterWeekdaySaturday,
      l10n.waterWeekdaySunday,
    ];
    final String days = reminder.daysOfWeek
        .map((int day) => names[day - 1])
        .join(' · ');
    if (days.isEmpty) return l10n.waterReminderDaily;
    return days;
  }

  String _formatTime(String hhmm) {
    final List<String> parts = hhmm.split(':');
    if (parts.length != 2) return hhmm.toBanglaDigits();
    final int hour = int.tryParse(parts[0]) ?? 0;
    final int minute = int.tryParse(parts[1]) ?? 0;
    return DateFormat('h:mm a')
        .format(DateTime(0, 1, 1, hour, minute))
        .toBanglaDigits();
  }
}

class _ReminderEditorSheet extends StatefulWidget {
  const _ReminderEditorSheet({this.existing});

  final Reminder? existing;

  @override
  State<_ReminderEditorSheet> createState() => _ReminderEditorSheetState();
}

class _ReminderEditorSheetState extends State<_ReminderEditorSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late TimeOfDay _time = _parse(widget.existing?.time ?? '08:00');
  late final Set<int> _days =
      Set<int>.from(widget.existing?.daysOfWeek ?? const <int>[]);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  TimeOfDay _parse(String hhmm) {
    final List<String> parts = hhmm.split(':');
    final int hour = int.tryParse(parts.isEmpty ? '' : parts[0]) ?? 8;
    final int minute = parts.length < 2 ? 0 : (int.tryParse(parts[1]) ?? 0);
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final String title = _title.text.trim();
    if (title.isEmpty) {
      AppSnackbar.info(context, l10n.formFieldInvalid);
      return;
    }
    final String time =
        '${_time.hour.toString().padLeft(2, '0')}:'
        '${_time.minute.toString().padLeft(2, '0')}';
    final List<int> days = _days.toList()..sort();

    try {
      final Reminder? existing = widget.existing;
      if (existing != null) {
        await updateWaterReminder(
          ref,
          existing.copyWith(title: title, time: time, daysOfWeek: days),
        );
      } else {
        await createWaterReminder(
          ref,
          title: title,
          body: l10n.waterReminderNotificationBody,
          time: time,
          daysOfWeek: days,
        );
      }
      if (context.mounted) {
        Navigator.of(context).pop();
        AppSnackbar.success(context, l10n.waterReminderSaved);
      }
    } on Exception {
      if (context.mounted) {
        AppSnackbar.error(context, l10n.commonError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<(int, String)> weekdays = <(int, String)>[
      (1, l10n.waterWeekdayMonday),
      (2, l10n.waterWeekdayTuesday),
      (3, l10n.waterWeekdayWednesday),
      (4, l10n.waterWeekdayThursday),
      (5, l10n.waterWeekdayFriday),
      (6, l10n.waterWeekdaySaturday),
      (7, l10n.waterWeekdaySunday),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SafeArea(
          top: false,
          child: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outlineVariant,
                          borderRadius: AppRadius.pillRadius,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      widget.existing == null
                          ? l10n.waterReminderAddTitle
                          : l10n.waterEditEntry,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _title,
                      autofocus: true,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: l10n.waterReminderNotificationTitle,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    InkWell(
                      onTap: _pickTime,
                      borderRadius: AppRadius.mdRadius,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: AppRadius.mdRadius,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                '${l10n.waterReminderTime}: '
                                '${DateFormat('h:mm a').format(DateTime(0, 1, 1, _time.hour, _time.minute)).toBanglaDigits()}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.waterReminderDays,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final (int day, String name) in weekdays)
                          FilterChip(
                            label: Text(name),
                            selected: _days.contains(day),
                            onSelected: (bool selected) {
                              setState(() {
                                if (selected) {
                                  _days.add(day);
                                } else {
                                  _days.remove(day);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      onPressed: () => _save(context, ref),
                      label: l10n.commonSave,
                      icon: Icons.check_rounded,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
