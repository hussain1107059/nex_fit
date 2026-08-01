import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../domain/entities/weight_log.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/weight_providers.dart';

/// Result of the weight entry sheet.
class _WeightSheetResult {
  const _WeightSheetResult({
    required this.weightKg,
    required this.date,
    this.note,
  });

  final double weightKg;
  final DateTime date;
  final String? note;
}

/// Bottom sheet used both to log a new weight and to edit an existing entry.
Future<void> showWeightEntrySheet(
  BuildContext context,
  WidgetRef ref, {
  WeightLog? existing,
}) async {
  final _WeightSheetResult? result = await showModalBottomSheet<_WeightSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WeightEntrySheet(existing: existing),
  );
  if (result == null || !context.mounted) return;

  final AppLocalizations l10n = context.l10n;
  try {
    if (existing != null) {
      await updateWeightEntry(
        ref,
        existing.copyWith(
          weightKg: result.weightKg,
          loggedAt: result.date,
          note: result.note,
        ),
      );
      if (context.mounted) AppSnackbar.success(context, l10n.weightLogUpdated);
    } else {
      await addWeightEntry(
        ref,
        result.weightKg,
        date: result.date,
        note: result.note,
      );
      if (context.mounted) AppSnackbar.success(context, l10n.weightLogSuccess);
    }
  } on Exception catch (error) {
    if (context.mounted) {
      AppSnackbar.error(context, _messageFor(error, l10n));
    }
  }
}

class _WeightEntrySheet extends StatefulWidget {
  const _WeightEntrySheet({this.existing});

  final WeightLog? existing;

  @override
  State<_WeightEntrySheet> createState() => _WeightEntrySheetState();
}

class _WeightEntrySheetState extends State<_WeightEntrySheet> {
  late final TextEditingController _weight = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.weightKg.toStringAsFixed(1),
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.existing?.note ?? '',
  );
  late DateTime _date = widget.existing?.loggedAt ?? DateTime.now();

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        );
      });
    }
  }

  void _submit() {
    final double? weight = double.tryParse(_weight.text);
    if (weight == null || weight <= 0) {
      AppSnackbar.info(context, context.l10n.errorWeightNegative);
      return;
    }
    Navigator.of(context).pop(
      _WeightSheetResult(
        weightKg: weight,
        date: _date,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colorScheme.outlineVariant,
                      borderRadius: AppRadius.pillRadius,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.existing == null
                      ? l10n.weightLogTitle
                      : l10n.weightEditEntry,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _weight,
                  autofocus: widget.existing == null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.weightValue,
                    hintText: '72.5',
                    suffixText: l10n.dashboardKgUnit,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(
                    DateFormat('dd MMM yyyy, h:mm a')
                        .format(_date)
                        .toBanglaDigits(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _note,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.weightNote,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  onPressed: _submit,
                  label: l10n.commonSave,
                  icon: Icons.check_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet to set the target weight.
Future<void> showWeightGoalSheet(
  BuildContext context,
  WidgetRef ref,
  double? current,
) async {
  final double? goal = await showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GoalSheet(current: current),
  );
  if (goal == null || !context.mounted) return;

  try {
    await setWeightGoal(ref, goal);
    if (context.mounted) {
      AppSnackbar.success(context, context.l10n.weightGoalSaved);
    }
  } on Exception catch (error) {
    if (context.mounted) {
      AppSnackbar.error(context, _messageFor(error, context.l10n));
    }
  }
}

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({this.current});

  final double? current;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  static const List<int> _presets = <int>[60, 65, 70, 75, 80, 85];

  late final TextEditingController _custom = TextEditingController(
    text: widget.current == null
        ? ''
        : widget.current!.toStringAsFixed(1),
  );

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _submit(double goal) {
    if (goal < 20) {
      AppSnackbar.info(context, context.l10n.errorWeightGoalTooLow);
      return;
    }
    if (goal > 400) {
      AppSnackbar.info(context, context.l10n.errorWeightGoalTooHigh);
      return;
    }
    Navigator.of(context).pop(goal);
  }

  void _submitCustom() {
    final double? goal = double.tryParse(_custom.text);
    if (goal == null || goal <= 0) {
      AppSnackbar.info(context, context.l10n.errorWeightGoalTooLow);
      return;
    }
    _submit(goal);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colorScheme.outlineVariant,
                    borderRadius: AppRadius.pillRadius,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.weightGoalSheetTitle,
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.weightGoalSuggested,
                style: context.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final int preset in _presets)
                    ChoiceChip(
                      avatar: const Icon(
                        Icons.monitor_weight_rounded,
                        size: 16,
                      ),
                      label: Text(
                        '$preset ${l10n.dashboardKgUnit}'.toBanglaDigits(),
                      ),
                      selected: widget.current?.round() == preset,
                      onSelected: (_) => _submit(preset.toDouble()),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _custom,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.weightValue,
                        suffixText: l10n.dashboardKgUnit,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    onPressed: _submitCustom,
                    label: l10n.commonOk,
                    size: AppButtonSize.small,
                    fullWidth: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _messageFor(Exception error, AppLocalizations l10n) {
  final String text = error.toString();
  if (text.contains('errorWeightNegative')) return l10n.errorWeightNegative;
  if (text.contains('errorWeightUnrealistic')) {
    return l10n.errorWeightUnrealistic;
  }
  if (text.contains('errorWeightGoalTooLow')) {
    return l10n.errorWeightGoalTooLow;
  }
  if (text.contains('errorWeightGoalTooHigh')) {
    return l10n.errorWeightGoalTooHigh;
  }
  return l10n.commonError;
}
