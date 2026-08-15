import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../domain/entities/common_enums.dart';
import '../../../../domain/entities/fitness_goal.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/fitness_goal_providers.dart';

/// Result of the goal editor sheet.
class _GoalEditorResult {
  const _GoalEditorResult({
    required this.title,
    required this.goalType,
    this.targetValue,
    this.targetDate,
  });

  final String title;
  final GoalType goalType;
  final double? targetValue;
  final DateTime? targetDate;
}

/// Bottom sheet used to create a new user goal or edit an existing one.
Future<void> showGoalEditorSheet(
  BuildContext context,
  WidgetRef ref, {
  FitnessGoal? existing,
}) async {
  final _GoalEditorResult? result = await showModalBottomSheet<_GoalEditorResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GoalEditorSheet(existing: existing),
  );
  if (result == null || !context.mounted) return;

  final AppLocalizations l10n = context.l10n;
  try {
    if (existing != null) {
      await updateUserGoal(
        ref,
        existing.copyWith(
          title: result.title,
          goalType: result.goalType,
          targetValue: result.targetValue,
          targetDate: result.targetDate,
        ),
      );
      if (context.mounted) {
        AppSnackbar.success(context, l10n.goalUpdated);
      }
    } else {
      await createUserGoal(
        ref,
        goalType: result.goalType,
        title: result.title,
        targetValue: result.targetValue,
        targetDate: result.targetDate,
      );
      if (context.mounted) {
        AppSnackbar.success(context, l10n.goalSaved);
      }
    }
  } on Exception {
    if (context.mounted) {
      AppSnackbar.error(context, l10n.commonError);
    }
  }
}

class _GoalEditorSheet extends StatefulWidget {
  const _GoalEditorSheet({this.existing});

  final FitnessGoal? existing;

  @override
  State<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends State<_GoalEditorSheet> {
  late GoalType _goalType = widget.existing?.goalType ?? GoalType.weightLoss;
  late DateTime? _targetDate = widget.existing?.targetDate;
  late final TextEditingController _targetController = TextEditingController(
    text: widget.existing?.targetValue == null
        ? ''
        : widget.existing!.targetValue.toString(),
  );

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  String _typeTitle(AppLocalizations l10n, GoalType type) {
    return switch (type) {
      GoalType.weightLoss => l10n.goalWeightLoss,
      GoalType.weightGain => l10n.goalWeightGain,
      GoalType.maintainWeight => l10n.goalMaintainWeight,
      GoalType.muscleBuilding => l10n.goalMuscleGain,
      GoalType.generalFitness => l10n.goalGeneralFitness,
      GoalType.other => l10n.profileNotSet,
    };
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) {
      setState(() {
        _targetDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _submit() {
    final double? parsed = double.tryParse(_targetController.text.trim());
    final double? value = parsed != null && parsed > 0 ? parsed : null;
    if (parsed == null && _targetController.text.trim().isNotEmpty) {
      AppSnackbar.info(context, context.l10n.goalTargetValueRequired);
      return;
    }
    Navigator.of(context).pop(
      _GoalEditorResult(
        title: _typeTitle(context.l10n, _goalType),
        goalType: _goalType,
        targetValue: value,
        targetDate: _targetDate,
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
                      ? l10n.goalAdd
                      : l10n.goalEdit,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.goalTypeLabel,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final GoalType type in GoalType.values)
                      ChoiceChip(
                        label: Text(_typeTitle(l10n, type)),
                        selected: _goalType == type,
                        onSelected: (bool selected) {
                          if (selected) {
                            setState(() => _goalType = type);
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _targetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.goalTargetValue,
                    hintText: l10n.goalTargetValueHint,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(
                    _targetDate == null
                        ? l10n.goalTargetDate
                        : formatLocalizedDate(_targetDate!, l10n),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  onPressed: _submit,
                  label: l10n.commonSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}