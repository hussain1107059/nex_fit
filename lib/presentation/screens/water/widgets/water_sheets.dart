import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../domain/entities/water_log.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/water_providers.dart';

/// Returns a fully built water log for editing. Null when dismissed.
class _SheetResult {
  const _SheetResult({required this.amountMl, this.note});

  final int amountMl;
  final String? note;
}

/// Bottom sheet used both to log a custom amount and to edit an entry.
Future<void> showCustomWaterSheet(
  BuildContext context,
  WidgetRef ref, {
  WaterLog? existing,
}) async {
  final _SheetResult? result = await showModalBottomSheet<_SheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomWaterSheet(existing: existing),
  );
  if (result == null || !context.mounted) return;

  final AppLocalizations l10n = context.l10n;
  try {
    if (existing != null) {
      await updateWaterEntry(
        ref,
        existing.copyWith(amountMl: result.amountMl, note: result.note),
      );
      if (context.mounted) AppSnackbar.success(context, l10n.waterLogUpdated);
    } else {
      await addWaterEntry(ref, result.amountMl, note: result.note);
      if (context.mounted) AppSnackbar.success(context, l10n.waterLogSuccess);
    }
  } on Exception catch (error) {
    if (context.mounted) {
      AppSnackbar.error(context, _messageFor(error, l10n));
    }
  }
}

class _CustomWaterSheet extends StatefulWidget {
  const _CustomWaterSheet({this.existing});

  final WaterLog? existing;

  @override
  State<_CustomWaterSheet> createState() => _CustomWaterSheetState();
}

class _CustomWaterSheetState extends State<_CustomWaterSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.existing == null ? '' : widget.existing!.amountMl.toString(),
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.existing?.note ?? '',
  );

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final int? amount = int.tryParse(_amount.text);
    if (amount == null || amount <= 0) {
      AppSnackbar.info(context, context.l10n.errorWaterNegative);
      return;
    }
    Navigator.of(context).pop(
      _SheetResult(amountMl: amount, note: _note.text.trim()),
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
                      ? l10n.waterCustomAmount
                      : l10n.waterEditEntry,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _amount,
                  autofocus: widget.existing == null,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.waterCustomAmount,
                    hintText: '500',
                    suffixText: l10n.dashboardMlUnit,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _note,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.waterNote,
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

/// Bottom sheet to pick a daily hydration goal.
Future<void> showWaterGoalSheet(BuildContext context, WidgetRef ref, int current) async {
  final int? goal = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GoalSheet(current: current),
  );
  if (goal == null || !context.mounted) return;

  try {
    await setWaterGoal(ref, goal);
    if (context.mounted) {
      AppSnackbar.success(context, context.l10n.waterGoalSaved);
    }
  } on Exception catch (error) {
    if (context.mounted) {
      AppSnackbar.error(context, _messageFor(error, context.l10n));
    }
  }
}

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.current});

  final int current;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  static const List<int> _presets = <int>[1500, 2000, 2500, 3000];

  late int _selected;
  final TextEditingController _custom = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _submit(int goal) {
    if (goal < 500) {
      AppSnackbar.info(context, context.l10n.errorWaterGoalTooLow);
      return;
    }
    Navigator.of(context).pop(goal);
  }

  void _submitCustom() {
    final int? goal = int.tryParse(_custom.text);
    if (goal == null || goal <= 0) {
      AppSnackbar.info(context, context.l10n.errorWaterGoalTooLow);
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
                l10n.waterGoalSheetTitle,
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.waterGoalSuggested,
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
                      avatar: const Icon(Icons.water_drop_rounded, size: 16),
                      label: Text(
                        '$preset ${l10n.dashboardMlUnit}'.toBanglaDigits(),
                      ),
                      selected: _selected == preset,
                      onSelected: (_) {
                        setState(() => _selected = preset);
                        _submit(preset);
                      },
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _custom,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.waterCustomAmount,
                        suffixText: l10n.dashboardMlUnit,
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
  if (text.contains('errorWaterNegative')) return l10n.errorWaterNegative;
  if (text.contains('errorWaterUnrealistic')) return l10n.errorWaterUnrealistic;
  if (text.contains('errorWaterGoalTooLow')) return l10n.errorWaterGoalTooLow;
  if (text.contains('errorWaterGoalTooHigh')) return l10n.errorWaterGoalTooHigh;
  return l10n.commonError;
}
