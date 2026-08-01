import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../core/widgets/dialogs/app_dialog.dart';
import '../../../../domain/entities/water_log.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/water_providers.dart';
import 'water_sheets.dart';

/// A single logged water entry with edit/delete actions.
class WaterEntryTile extends ConsumerWidget {
  const WaterEntryTile({super.key, required this.log});

  final WaterLog log;

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
          child: Icon(Icons.water_drop_rounded, size: 20, color: accent),
        ),
        title: Text(
          '${log.amountMl.toString().toBanglaDigits()} ${l10n.dashboardMlUnit}',
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
        trailing: Text(
          DateFormat('h:mm a').format(log.loggedAt).toBanglaDigits(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        onTap: () => showCustomWaterSheet(context, ref, existing: log),
        onLongPress: () => _confirmDelete(context, ref),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: l10n.waterDeleteEntry,
      message: l10n.waterDeleteEntryMessage,
      confirmLabel: l10n.commonDelete,
    );
    if (confirmed != true || !context.mounted) return;
    await deleteWaterEntry(ref, log.id!);
    if (context.mounted) {
      AppSnackbar.success(context, l10n.waterLogDeleted);
    }
  }
}
