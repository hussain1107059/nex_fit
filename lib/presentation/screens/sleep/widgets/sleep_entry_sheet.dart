import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../domain/entities/sleep_log.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/sleep_providers.dart';

/// Result of the sleep entry sheet.
class _SleepEntryResult {
  const _SleepEntryResult({
    required this.sleepDate,
    required this.durationMinutes,
    required this.quality,
    this.note,
  });

  final DateTime sleepDate;
  final int durationMinutes;
  final int quality;
  final String? note;
}

/// Bottom sheet used both to log a new night and to edit an existing entry.
Future<void> showSleepEntrySheet(
  BuildContext context,
  WidgetRef ref, {
  SleepLog? existing,
}) async {
  final _SleepEntryResult? result = await showModalBottomSheet<_SleepEntryResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SleepEntrySheet(existing: existing),
  );
  if (result == null || result.durationMinutes <= 0 || !context.mounted) return;

  final AppLocalizations l10n = context.l10n;
  try {
    if (existing != null) {
      await updateSleepEntry(
        ref,
        existing.copyWith(
          sleepDate: result.sleepDate,
          durationMinutes: result.durationMinutes,
          quality: result.quality,
          note: result.note,
        ),
      );
      if (context.mounted) {
        AppSnackbar.success(context, l10n.sleepLogUpdated);
      }
    } else {
      await addSleepEntry(
        ref,
        sleepDate: result.sleepDate,
        durationMinutes: result.durationMinutes,
        quality: result.quality,
        note: result.note,
      );
      if (context.mounted) {
        AppSnackbar.success(context, l10n.sleepLogSaved);
      }
    }
  } on Exception {
    if (context.mounted) {
      AppSnackbar.error(context, l10n.commonError);
    }
  }
}

class _SleepEntrySheet extends StatefulWidget {
  const _SleepEntrySheet({this.existing});

  final SleepLog? existing;

  @override
  State<_SleepEntrySheet> createState() => _SleepEntrySheetState();
}

class _SleepEntrySheetState extends State<_SleepEntrySheet> {
  static const List<int> _presets = <int>[360, 420, 480, 540, 600];

  late DateTime _sleepDate = widget.existing?.sleepDate ?? DateTime.now();
  late int _duration = widget.existing?.durationMinutes ?? 480;
  late int _quality = widget.existing?.quality ?? 3;
  late final TextEditingController _custom = TextEditingController();
  late final TextEditingController _note = TextEditingController(
    text: widget.existing?.note ?? '',
  );

  @override
  void dispose() {
    _custom.dispose();
    _note.dispose();
    super.dispose();
  }

  String _label(int minutes) {
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    final String h = context.l10n.dashboardSleepHour;
    final String m = context.l10n.dashboardSleepMinute;
    return '${'$hours$h'.toBanglaDigits()} ${'$rest$m'.toBanglaDigits()}';
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _sleepDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _sleepDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _submit() {
    final int? custom = int.tryParse(_custom.text);
    if (custom != null && custom > 0) _duration = custom;
    if (_duration <= 0) {
      AppSnackbar.info(context, context.l10n.formFieldInvalid);
      return;
    }
    Navigator.of(context).pop(
      _SleepEntryResult(
        sleepDate: _sleepDate,
        durationMinutes: _duration,
        quality: _quality,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
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
                      ? l10n.sleepLogTitle
                      : l10n.sleepEditEntry,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.dashboardLogSleepHint,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final int preset in _presets)
                      ActionChip(
                        avatar: const Icon(Icons.bedtime_rounded, size: 16),
                        label: Text(_label(preset)),
                        onPressed: () => setState(() => _duration = preset),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
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
                          hintText: l10n.dashboardLogSleepCustomHint,
                          suffixText: l10n.dashboardSleepMinute,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(
                      onPressed: _submit,
                      label: l10n.commonSave,
                      size: AppButtonSize.small,
                      fullWidth: false,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Slider(
                        value: _quality.toDouble(),
                        max: 5,
                        divisions: 5,
                        label: '$_quality/5',
                        onChanged: (double value) =>
                            setState(() => _quality = value.round()),
                      ),
                    ),
                    Text(
                      '$_quality/5'.toBanglaDigits(),
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(formatLocalizedDate(_sleepDate, l10n)),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _note,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.sleepEntryNote,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}