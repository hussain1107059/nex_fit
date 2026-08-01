import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/dialogs/app_dialog.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../domain/entities/body_measurement.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/weight_providers.dart';
import 'measurement_sheets.dart';

/// A single body measurement record listing every recorded circumference.
class BodyMeasurementTile extends ConsumerWidget {
  const BodyMeasurementTile({super.key, required this.measurement});

  final BodyMeasurement measurement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    final List<MapEntry<MeasurementType, double>> values =
        <MapEntry<MeasurementType, double>>[
      for (final MeasurementType type in MeasurementType.values)
        if (type.read(measurement) != null)
          MapEntry<MeasurementType, double>(type, type.read(measurement)!),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showMeasurementSheet(
          context,
          ref,
          existing: measurement,
        ),
        onLongPress: () => _confirmDelete(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.straighten_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      DateFormat('dd MMM yyyy')
                          .format(measurement.measuredAt)
                          .toBanglaDigits(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${values.length.toString().toBanglaDigits()} '
                    '${l10n.measurementParts}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final MapEntry<MeasurementType, double> entry in values)
                    _ValueChip(
                      label: measurementLabel(context, entry.key),
                      value: entry.value,
                    ),
                ],
              ),
              if (measurement.note != null &&
                  measurement.note!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  measurement.note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: l10n.measurementDeleteTitle,
      message: l10n.measurementDeleteMessage,
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true || !context.mounted) return;
    await deleteBodyMeasurement(ref, measurement.id!);
    if (context.mounted) {
      AppSnackbar.success(context, l10n.measurementDeleted);
    }
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.6,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${value.toStringAsFixed(1)} ${context.l10n.dashboardCmUnit}'
                .toBanglaDigits(),
            style: context.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
