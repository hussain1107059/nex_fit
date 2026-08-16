import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../providers/backup_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_providers.dart';
import '../../../router/app_router.dart';

/// Compact premium card showing the Drive backup status with a quick
/// "Back up now" action. Tapping opens the full backup & restore screen.
class BackupCard extends ConsumerWidget {
  const BackupCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      return const SizedBox.shrink();
    }

    final AppSettings? settings =
        ref.watch(settingsControllerProvider).valueOrNull;
    final BackupUiState ui = ref.watch(backupControllerProvider);
    final AsyncValue<bool> connected = ref.watch(driveConnectedProvider);

    final DateTime? lastBackupAt = settings?.lastBackupAt;
    final bool isBusy = ui.isBusy;

    final String statusText = isBusy
        ? switch (ui.activity) {
            BackupActivity.restoring =>
              context.l10n.settingsBackupProgressRestoring,
            _ => context.l10n.settingsBackupProgressUploading,
          }
        : lastBackupAt == null
        ? context.l10n.backupNever
        : DateFormat(
            'dd MMM yyyy, h:mm a',
          ).format(lastBackupAt);

    final Color iconColor = connected.valueOrNull == true
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlRadius,
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
            Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: InkWell(
        borderRadius: AppRadius.xlRadius,
        onTap: () => context.push(AppRoutes.settingsBackup),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  connected.valueOrNull == true
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: iconColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.l10n.settingsBackupRestore,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!isBusy)
                  IconButton(
                    tooltip: context.l10n.settingsBackupNow,
                    onPressed: () => _backupNow(context, ref),
                    icon: const Icon(Icons.backup_rounded),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (isBusy) ...[
              LinearProgressIndicator(
                value: ui.progress.clamp(0.0, 1.0),
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                statusText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${context.l10n.settingsLastBackup}: $statusText',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                connected.valueOrNull == true
                    ? context.l10n.settingsDriveConnected
                    : context.l10n.settingsDriveDisconnected,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: connected.valueOrNull == true
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _backupNow(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(backupControllerProvider.notifier).createBackup();
      if (context.mounted) {
        AppSnackbar.success(context, context.l10n.settingsBackupSuccess);
      }
    } on Exception {
      if (context.mounted) {
        final BackupUiState ui = ref.read(backupControllerProvider);
        AppSnackbar.error(
          context,
          localizeFailureMessage(
            context.l10n,
            ui.errorKey ?? 'backupFailed',
          ),
        );
      }
    }
  }
}
