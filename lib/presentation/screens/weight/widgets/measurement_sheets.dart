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
import '../../../../domain/entities/body_measurement.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/weight_providers.dart';

/// Result of the measurement entry sheet.
class _MeasurementSheetResult {
  const _MeasurementSheetResult({
    required this.values,
    required this.date,
    this.note,
  });

  final Map<MeasurementType, double?> values;
  final DateTime date;
  final String? note;
}

/// Bottom sheet used both to add and to edit a body measurement record.
/// Pass [userId] when creating a new record (ignored when [existing] is set).
Future<void> showMeasurementSheet(
  BuildContext context,
  WidgetRef ref, {
  String? userId,
  BodyMeasurement? existing,
}) async {
  final _MeasurementSheetResult? result =
      await showModalBottomSheet<_MeasurementSheetResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MeasurementSheet(existing: existing),
      );
  if (result == null || !context.mounted) return;

  final AppLocalizations l10n = context.l10n;
  try {
    if (existing != null) {
      await updateBodyMeasurement(ref, _applyValues(existing, result));
      if (context.mounted) {
        AppSnackbar.success(context, l10n.measurementUpdated);
      }
    } else {
      if (userId == null) return;
      await addBodyMeasurement(
        ref,
        _applyValues(
          BodyMeasurement(
            userId: userId,
            measuredAt: result.date,
            createdAt: DateTime.now(),
          ),
          result,
        ),
      );
      if (context.mounted) {
        AppSnackbar.success(context, l10n.measurementAdded);
      }
    }
  } on Exception catch (error) {
    if (context.mounted) {
      AppSnackbar.error(context, _messageFor(error, l10n));
    }
  }
}

class _MeasurementSheet extends StatefulWidget {
  const _MeasurementSheet({this.existing});

  final BodyMeasurement? existing;

  @override
  State<_MeasurementSheet> createState() => _MeasurementSheetState();
}

class _MeasurementSheetState extends State<_MeasurementSheet> {
  late final Map<MeasurementType, TextEditingController> _controllers = {
    for (final MeasurementType type in MeasurementType.values)
      type: TextEditingController(text: _initialText(type)),
  };
  late final TextEditingController _note = TextEditingController(
    text: widget.existing?.note ?? '',
  );
  late DateTime _date = widget.existing?.measuredAt ?? DateTime.now();

  String _initialText(MeasurementType type) {
    if (widget.existing == null) return '';
    final double? value = type.read(widget.existing!);
    return value == null ? '' : value.toStringAsFixed(1);
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
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
        _date = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _submit() {
    final Map<MeasurementType, double?> values =
        <MeasurementType, double?>{};
    for (final MeasurementType type in MeasurementType.values) {
      final String text = _controllers[type]!.text.trim();
      if (text.isEmpty) {
        values[type] = null;
        continue;
      }
      final double? value = double.tryParse(text);
      if (value == null || value <= 0) {
        AppSnackbar.info(context, context.l10n.errorMeasurementInvalid);
        return;
      }
      values[type] = value;
    }
    if (values.values.every((double? value) => value == null)) {
      AppSnackbar.info(context, context.l10n.errorMeasurementEmpty);
      return;
    }
    Navigator.of(context).pop(
      _MeasurementSheetResult(
        values: values,
        date: _date,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final double fieldWidth =
        (MediaQuery.sizeOf(context).width - AppSpacing.lg * 2 - 24) / 2;

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
                      ? l10n.measurementAddTitle
                      : l10n.measurementEditTitle,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.measurementAddSubtitle,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final MeasurementType type in MeasurementType.values)
                      SizedBox(
                        width: fieldWidth,
                        child: _MeasurementField(
                          type: type,
                          controller: _controllers[type]!,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(
                    DateFormat('dd MMM yyyy').format(_date).toBanglaDigits(),
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

class _MeasurementField extends StatelessWidget {
  const _MeasurementField({required this.type, required this.controller});

  final MeasurementType type;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      decoration: InputDecoration(
        labelText: measurementLabel(context, type),
        suffixText: context.l10n.dashboardCmUnit,
        isDense: true,
      ),
    );
  }
}

/// Localized label for a body part.
String measurementLabel(BuildContext context, MeasurementType type) {
  final AppLocalizations l10n = context.l10n;
  return switch (type) {
    MeasurementType.chest => l10n.measurementChest,
    MeasurementType.waist => l10n.measurementWaist,
    MeasurementType.hip => l10n.measurementHip,
    MeasurementType.neck => l10n.measurementNeck,
    MeasurementType.leftArm => l10n.measurementLeftArm,
    MeasurementType.rightArm => l10n.measurementRightArm,
    MeasurementType.leftThigh => l10n.measurementLeftThigh,
    MeasurementType.rightThigh => l10n.measurementRightThigh,
    MeasurementType.leftCalf => l10n.measurementLeftCalf,
    MeasurementType.rightCalf => l10n.measurementRightCalf,
  };
}

BodyMeasurement _applyValues(
  BodyMeasurement measurement,
  _MeasurementSheetResult result,
) {
  BodyMeasurement updated = measurement;
  for (final MapEntry<MeasurementType, double?> entry in result.values.entries) {
    updated = entry.key.withValue(updated, entry.value);
  }
  final String? note = result.note;
  return updated.copyWith(
    measuredAt: result.date,
    note: note == null || note.isEmpty ? null : note,
  );
}

String _messageFor(Exception error, AppLocalizations l10n) {
  if (error.toString().contains('errorMeasurement')) {
    return l10n.errorMeasurementInvalid;
  }
  return l10n.commonError;
}
