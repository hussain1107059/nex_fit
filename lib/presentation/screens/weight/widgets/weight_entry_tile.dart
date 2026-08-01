import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/widgets/dialogs/app_dialog.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../domain/entities/weight_log.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/weight_providers.dart';
import 'weight_sheets.dart';

/// A single logged weight entry with edit/delete actions.
class WeightEntryTile extends ConsumerWidget {
  const WeightEntryTile({super.key, required this.log});

  final WeightLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Color accent = theme.colorScheme.tertiary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.monitor_weight_rounded, size: 20, color: accent),
        ),
        title: Text(
          '${log.weightKg.toStringAsFixed(1)} ${l10n.dashboardKgUnit}'
              .toBanglaDigits(),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: log.note == null || log.note!.isEmpty
            ? null
            : Text(
                log.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              DateFormat('dd MMM').format(log.loggedAt).toBanglaDigits(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              DateFormat('h:mm a').format(log.loggedAt).toBanglaDigits(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
        onTap: () => showWeightEntrySheet(context, ref, existing: log),
        onLongPress: () => _confirmDelete(context, ref),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: l10n.weightDeleteEntry,
      message: l10n.weightDeleteEntryMessage,
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true || !context.mounted) return;
    await deleteWeightEntry(ref, log.id!);
    if (context.mounted) {
      AppSnackbar.success(context, l10n.weightLogDeleted);
    }
  }
}
