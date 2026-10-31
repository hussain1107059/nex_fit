import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../domain/entities/activity.dart';
import '../../../../l10n/app_localizations.dart';
import 'activity_type_style.dart';

/// Result of the target picker. A null [goal] means "start without a target".
class ActivityGoalSelection {
  const ActivityGoalSelection(this.goal);

  final ActivityGoal? goal;
}

/// Lets the user choose a distance or step target before starting [type].
Future<ActivityGoalSelection?> showActivityGoalSheet(
  BuildContext context, {
  required ActivityType type,
}) {
  return showModalBottomSheet<ActivityGoalSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    builder: (BuildContext context) => _ActivityGoalSheet(type: type),
  );
}

enum _TargetMode { none, distance, steps }

class _ActivityGoalSheet extends StatefulWidget {
  const _ActivityGoalSheet({required this.type});

  final ActivityType type;

  @override
  State<_ActivityGoalSheet> createState() => _ActivityGoalSheetState();
}

class _ActivityGoalSheetState extends State<_ActivityGoalSheet> {
  final TextEditingController _valueController = TextEditingController();
  _TargetMode _mode = _TargetMode.none;
  String? _error;

  bool get _supportsSteps =>
      widget.type.supportsStepTarget &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _selectMode(_TargetMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _valueController.clear();
    });
  }

  void _applyQuickValue(String value) {
    setState(() {
      _error = null;
      _valueController.text = value;
      _valueController.selection = TextSelection.collapsed(
        offset: value.length,
      );
    });
  }

  void _submit() {
    if (_mode == _TargetMode.none) {
      Navigator.of(context).pop(const ActivityGoalSelection(null));
      return;
    }
    final double? value = _parseValue(_valueController.text);
    if (value == null || value <= 0) {
      setState(() => _error = context.l10n.activityTargetInvalid);
      return;
    }
    final ActivityGoal goal = _mode == _TargetMode.distance
        ? ActivityGoal.distance(value * 1000)
        : ActivityGoal.steps(value);
    Navigator.of(context).pop(ActivityGoalSelection(goal));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = AppColors.light;
    final Color accent = widget.type.color(colors);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: AppRadius.smRadius,
                ),
                child: Icon(widget.type.icon, color: accent),
              ),
              AppSpacing.sm.widthSpace,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.activityTargetTitle,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      widget.type.label(l10n),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.md.heightSpace,
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              ChoiceChip(
                label: Text(l10n.activityTargetNone),
                selected: _mode == _TargetMode.none,
                onSelected: (_) => _selectMode(_TargetMode.none),
              ),
              ChoiceChip(
                label: Text(l10n.activityTargetDistance),
                selected: _mode == _TargetMode.distance,
                onSelected: (_) => _selectMode(_TargetMode.distance),
              ),
              if (_supportsSteps)
                ChoiceChip(
                  label: Text(l10n.activityTargetSteps),
                  selected: _mode == _TargetMode.steps,
                  onSelected: (_) => _selectMode(_TargetMode.steps),
                ),
            ],
          ),
          if (_mode != _TargetMode.none) ...<Widget>[
            AppSpacing.md.heightSpace,
            TextField(
              controller: _valueController,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(
                decimal: _mode == _TargetMode.distance,
              ),
              decoration: InputDecoration(
                labelText: _mode == _TargetMode.distance
                    ? l10n.activityTargetHintDistance
                    : l10n.activityTargetHintSteps,
                suffixText: _mode == _TargetMode.distance
                    ? l10n.activityKm
                    : l10n.activitySteps,
                errorText: _error,
                border: OutlineInputBorder(borderRadius: AppRadius.smRadius),
              ),
              onSubmitted: (_) => _submit(),
            ),
            AppSpacing.sm.heightSpace,
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final String value
                    in _mode == _TargetMode.distance
                        ? const <String>['1', '2', '5', '10']
                        : const <String>['1000', '2000', '5000', '10000'])
                  ActionChip(
                    label: Text(value),
                    onPressed: () => _applyQuickValue(value),
                  ),
              ],
            ),
          ],
          AppSpacing.lg.heightSpace,
          AppButton(
            label: l10n.activityStart,
            icon: Icons.play_arrow_rounded,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  static double? _parseValue(String raw) {
    final String normalized = raw.trim().replaceAllMapped(
      RegExp('[০-৯]'),
      (Match match) => '০১২৩৪৫৬৭৮৯'.indexOf(match[0]!).toString(),
    );
    return double.tryParse(normalized);
  }
}
