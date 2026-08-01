import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../data/services/notifications/reminder_schedule.dart';
import '../../../domain/entities/common_enums.dart';
import '../../../domain/entities/reminder.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/reminder_providers.dart';
import 'reminder_ui.dart';

/// Create / edit screen for a single reminder with full scheduling, multiple
/// times per day, notification options and duplicate / invalid-time checks.
class ReminderEditorScreen extends ConsumerStatefulWidget {
  const ReminderEditorScreen({super.key, this.existing});

  final Reminder? existing;

  @override
  ConsumerState<ReminderEditorScreen> createState() =>
      _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends ConsumerState<ReminderEditorScreen> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final TextEditingController _body = TextEditingController(
    text: widget.existing?.body ?? '',
  );
  late ReminderType _type = widget.existing?.reminderType ?? ReminderType.custom;
  late ReminderScheduleType _schedule =
      widget.existing?.scheduleType ?? ReminderScheduleType.daily;
  late final List<TimeOfDay> _times =
      (widget.existing?.allTimes ?? <String>['08:00'])
          .map(_parseTime)
          .toList();
  late final List<int> _days =
      List<int>.from(widget.existing?.daysOfWeek ?? <int>[]);
  late DateTime? _startDate = widget.existing?.startDate;
  late int _monthDay = widget.existing?.monthDay ?? DateTime.now().day;
  late bool _sound = widget.existing?.soundEnabled ?? true;
  late bool _vibration = widget.existing?.vibrationEnabled ?? true;
  late bool _silent = widget.existing?.silentMode ?? false;
  late bool _actions = widget.existing?.showActionButtons ?? true;

  bool _saving = false;

  static const List<int> _weekdays = <int>[1, 2, 3, 4, 5, 6, 7];

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(String hhmm) {
    final (int hour, int minute) = parseHhmm(hhmm);
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _pickTime(int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );
    if (picked == null || !mounted) return;
    setState(() => _times[index] = picked);
  }

  Future<void> _addTime() async {
    if (_times.length >= 8) {
      AppSnackbar.info(context, context.l10n.remindersMaxTimes);
      return;
    }
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _times.last,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (!_times.contains(picked)) _times.add(picked);
    });
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked == null || !mounted) return;
    setState(() => _startDate = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    final String title = _title.text.trim();
    if (title.isEmpty) {
      AppSnackbar.info(context, l10n.formFieldInvalid);
      return;
    }
    if (_times.isEmpty) {
      AppSnackbar.info(context, l10n.remindersErrorNoTime);
      return;
    }
    if ((_schedule == ReminderScheduleType.weekly ||
            _schedule == ReminderScheduleType.customDays) &&
        _days.isEmpty) {
      AppSnackbar.info(context, l10n.remindersErrorNoDays);
      return;
    }
    if (_schedule == ReminderScheduleType.oneTime && _startDate == null) {
      AppSnackbar.info(context, l10n.remindersErrorNoDate);
      return;
    }

    setState(() => _saving = true);
    try {
      final List<String> times = _times
          .map((TimeOfDay t) => formatHhmm(t.hour, t.minute))
          .toList()
        ..sort();
      final List<int> days =
          _schedule == ReminderScheduleType.weekly ||
              _schedule == ReminderScheduleType.customDays
          ? List<int>.from(_days)
          : const <int>[];
      days.sort();
      final DateTime now = DateTime.now();
      final Reminder draft = Reminder(
        userId: '',
        title: title,
        body: _body.text.trim().isEmpty ? null : _body.text.trim(),
        reminderType: _type,
        time: times.first,
        times: times.length > 1 ? times.sublist(1) : const <String>[],
        scheduleType: _schedule,
        daysOfWeek: days,
        startDate: _startDate,
        endDate: null,
        monthDay: _schedule == ReminderScheduleType.monthly ? _monthDay : null,
        colorValue: defaultColorFor(_type),
        soundEnabled: _sound,
        vibrationEnabled: _vibration,
        silentMode: _silent,
        showActionButtons: _actions,
        createdAt: now,
        updatedAt: now,
      );

      final Reminder? existing = widget.existing;
      if (existing == null) {
        await createReminder(ref, draft);
      } else {
        await updateReminder(
          ref,
          existing.copyWith(
            title: draft.title,
            body: draft.body,
            reminderType: draft.reminderType,
            time: draft.time,
            times: draft.times,
            scheduleType: draft.scheduleType,
            daysOfWeek: draft.daysOfWeek,
            startDate: draft.startDate,
            monthDay: draft.monthDay,
            colorValue: draft.colorValue,
            soundEnabled: draft.soundEnabled,
            vibrationEnabled: draft.vibrationEnabled,
            silentMode: draft.silentMode,
            showActionButtons: draft.showActionButtons,
          ),
        );
      }
      if (mounted) {
        context.pop();
        AppSnackbar.success(context, l10n.remindersSaved);
      }
    } on Exception catch (error) {
      if (!mounted) return;
      AppSnackbar.error(
        context,
        error is AppException ? error.message : l10n.commonError,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? l10n.remindersAdd
              : l10n.remindersEdit,
        ),
      ),
      body: _saving
          ? const LoadingWidget(message: '')
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              children: [
                TextField(
                  controller: _title,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.remindersTitleField,
                    prefixIcon: const Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _body,
                  maxLength: 120,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.remindersDescription,
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel(l10n.remindersType),
                const SizedBox(height: AppSpacing.sm),
                _TypeSelector(
                  selected: _type,
                  onChanged: (ReminderType type) =>
                      setState(() => _type = type),
                ),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel(l10n.remindersRepeat),
                const SizedBox(height: AppSpacing.sm),
                _ScheduleSelector(
                  selected: _schedule,
                  onChanged: (ReminderScheduleType schedule) => setState(() {
                    _schedule = schedule;
                    if (schedule == ReminderScheduleType.oneTime &&
                        _startDate == null) {
                      _startDate = DateTime.now();
                    }
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),
                _sectionLabel(l10n.remindersTime),
                const SizedBox(height: AppSpacing.sm),
                _TimeList(
                  times: _times,
                  onPick: _pickTime,
                  onAdd: _addTime,
                  onRemove: (int index) {
                    if (_times.length == 1) return;
                    setState(() => _times.removeAt(index));
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_schedule == ReminderScheduleType.oneTime) ...[
                  _sectionLabel(l10n.remindersDate),
                  const SizedBox(height: AppSpacing.sm),
                  InkWell(
                    onTap: _pickDate,
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
                            Icons.event_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              DateFormat('dd MMM yyyy').format(_startDate!),
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
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_schedule == ReminderScheduleType.weekly ||
                    _schedule == ReminderScheduleType.customDays) ...[
                  _sectionLabel(l10n.remindersDays),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final int day in _weekdays)
                        FilterChip(
                          label: Text(_dayName(l10n, day)),
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
                ],
                if (_schedule == ReminderScheduleType.monthly) ...[
                  _sectionLabel(l10n.remindersDayOfMonthLabel),
                  const SizedBox(height: AppSpacing.sm),
                  _MonthDaySelector(
                    value: _monthDay,
                    onChanged: (int value) => setState(() => _monthDay = value),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _sectionLabel(l10n.remindersNotification),
                const SizedBox(height: AppSpacing.xs),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.volume_up_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(l10n.remindersSound),
                  value: _sound && !_silent,
                  onChanged: (bool value) {
                    setState(() {
                      _sound = value;
                      if (value) _silent = false;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.vibration_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(l10n.remindersVibration),
                  value: _vibration && !_silent,
                  onChanged: (bool value) {
                    setState(() {
                      _vibration = value;
                      if (value) _silent = false;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.notifications_off_rounded,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(l10n.remindersSilent),
                  value: _silent,
                  onChanged: (bool value) {
                    setState(() {
                      _silent = value;
                      if (value) {
                        _sound = false;
                        _vibration = false;
                      }
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.touch_app_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(l10n.remindersActionButtons),
                  subtitle: Text(l10n.remindersActionButtonsSubtitle),
                  value: _actions,
                  onChanged: (bool value) =>
                      setState(() => _actions = value),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  onPressed: _save,
                  label: widget.existing == null
                      ? l10n.remindersCreate
                      : l10n.commonSave,
                  icon: Icons.check_rounded,
                  isLoading: _saving,
                ),
              ],
            ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }

  String _dayName(AppLocalizations l10n, int day) {
    const List<String> names = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return names[day - 1];
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

  final ReminderType selected;
  final ValueChanged<ReminderType> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<ReminderType> types = ReminderType.values;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.xs,
      crossAxisSpacing: AppSpacing.xs,
      childAspectRatio: 0.95,
      children: [
        for (final ReminderType type in types)
          _TypeTile(
            type: type,
            selected: type == selected,
            onTap: () => onChanged(type),
          ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ReminderType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = reminderTypeColor(type);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdRadius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdRadius,
          color: selected
              ? color.withValues(alpha: 0.16)
              : context.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: selected
                ? color
                : context.colorScheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              reminderTypeIcon(type),
              size: 22,
              color: selected ? color : context.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              reminderTypeLabel(context.l10n, type),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? context.colorScheme.onSurface
                    : context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleSelector extends StatelessWidget {
  const _ScheduleSelector({required this.selected, required this.onChanged});

  final ReminderScheduleType selected;
  final ValueChanged<ReminderScheduleType> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<ReminderScheduleType> types = ReminderScheduleType.values;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final ReminderScheduleType type in types)
          ChoiceChip(
            label: Text(scheduleTypeLabel(context.l10n, type)),
            selected: type == selected,
            onSelected: (bool value) {
              if (value) onChanged(type);
            },
          ),
      ],
    );
  }
}

class _TimeList extends StatelessWidget {
  const _TimeList({
    required this.times,
    required this.onPick,
    required this.onAdd,
    required this.onRemove,
  });

  final List<TimeOfDay> times;
  final ValueChanged<int> onPick;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < times.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => onPick(i),
                    borderRadius: AppRadius.mdRadius,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: context.colorScheme.surfaceContainerHighest,
                        borderRadius: AppRadius.mdRadius,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: context.colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            DateFormat('h:mm a')
                                .format(DateTime(
                                  0,
                                  1,
                                  1,
                                  times[i].hour,
                                  times[i].minute,
                                ))
                                .toBanglaDigits(),
                            style: context.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  onPressed: () => onRemove(i),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  tooltip: context.l10n.commonDelete,
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(context.l10n.remindersAddTime),
          ),
        ),
      ],
    );
  }
}

class _MonthDaySelector extends StatelessWidget {
  const _MonthDaySelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (int day = 1; day <= 31; day++)
          ChoiceChip(
            label: Text(day.toString().toBanglaDigits()),
            selected: value == day,
            onSelected: (bool selected) {
              if (selected) onChanged(day);
            },
          ),
      ],
    );
  }
}
