import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/widgets/dialogs/app_dialog.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/backup_history.dart';
import '../../../domain/entities/backup_metadata.dart';
import '../../../domain/entities/backup_preview.dart';
import '../../../domain/entities/common_enums.dart';
import '../../../domain/entities/remote_backup_file.dart';
import '../../../data/services/sync/sync_engine.dart';
import '../../../injection/dependency_injection.dart';
import '../../providers/backup_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/sync_providers.dart';
import 'widgets/settings_widgets.dart';

/// Google Drive Backup & Restore: manual/automatic encrypted backups of the
/// whole database, cloud history, preview + restore with conflict detection.
class BackupSettingsScreen extends ConsumerStatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  ConsumerState<BackupSettingsScreen> createState() =>
      _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final AppSettings? settings =
        ref.watch(settingsControllerProvider).valueOrNull;
    final BackupUiState ui = ref.watch(backupControllerProvider);
    final AsyncValue<bool> connected = ref.watch(driveConnectedProvider);
    final AsyncValue<List<RemoteBackupFile>> remote =
        ref.watch(remoteBackupsProvider);
    final AsyncValue<List<BackupHistory>> history =
        ref.watch(backupHistoryProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    final bool canBackup = !ui.isBusy && connected.valueOrNull == true;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsBackupRestore)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          _buildDriveCard(connected),
          const SizedBox(height: AppSpacing.sm),
          _buildBackupAction(ui, canBackup),
          const SizedBox(height: AppSpacing.sm),
          _buildSyncStatusCard(),
          const SizedBox(height: AppSpacing.lg),
          SettingsSectionTitle(context.l10n.settingsAutoBackup),
          SettingsCard(
            children: [
              SettingsSwitchTile(
                icon: Icons.backup_rounded,
                title: context.l10n.settingsAutoBackup,
                subtitle: context.l10n.settingsAutoBackupSubtitle,
                value: settings?.backupEnabled ?? true,
                onChanged: (bool value) => controller.setBackupEnabled(value),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.schedule_rounded,
                title: context.l10n.settingsBackupSchedule,
                value: _scheduleLabel(
                  context,
                  settings?.backupSchedule ?? BackupSchedule.manual,
                ),
                onTap: () => _pickSchedule(controller, settings),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.layers_rounded,
                title: context.l10n.settingsBackupRetention,
                subtitle: context.l10n.settingsBackupRetentionSubtitle,
                value: '${settings?.backupRetentionCount ?? 5}',
                onTap: () => _pickRetention(controller, settings),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsSwitchTile(
                icon: Icons.wifi_rounded,
                title: context.l10n.settingsBackupOnWifiOnly,
                subtitle: context.l10n.settingsBackupOnWifiOnlySubtitle,
                value: settings?.backupOnWifiOnly ?? false,
                onChanged: (bool value) =>
                    controller.setBackupOnWifiOnly(value),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsSwitchTile(
                icon: Icons.battery_charging_full_rounded,
                title: context.l10n.settingsBackupWhileCharging,
                subtitle: context.l10n.settingsBackupWhileChargingSubtitle,
                value: settings?.backupWhileCharging ?? false,
                onChanged: (bool value) =>
                    controller.setBackupWhileCharging(value),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsSectionTitle(context.l10n.settingsRemoteBackups),
          remote.when(
            data: (files) => files.isEmpty
                ? _EmptyBackupsCard(
                    connected: connected.valueOrNull == true,
                    onConnect: _connectDrive,
                  )
                : _RemoteBackupsList(
                    files: files,
                    busy: ui.isBusy,
                    onRestore: _restoreBackup,
                    onDelete: _deleteBackup,
                  ),
            loading: () => const _LoadingCard(),
            error: (Object error, StackTrace stackTrace) => SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_off_rounded),
                  title: Text(
                    localizeFailureMessage(
                      context.l10n,
                      _messageKeyOf(error),
                    ),
                  ),
                  trailing: IconButton(
                    onPressed: () {
                      ref.invalidate(driveConnectedProvider);
                      ref.invalidate(remoteBackupsProvider);
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsSectionTitle(context.l10n.settingsLastBackup),
          history.when(
            data: (entries) => entries.isEmpty
                ? SettingsCard(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.history_rounded),
                        title: Text(context.l10n.backupNever),
                      ),
                    ],
                  )
                : _BackupHistoryList(entries: entries),
            loading: () => const _LoadingCard(),
            error: (Object error, StackTrace stackTrace) =>
                const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.logout_rounded,
                title: context.l10n.settingsSignOutDrive,
                subtitle: context.l10n.settingsSignOutDriveSubtitle,
                showChevron: false,
                onTap: _signOut,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDriveCard(AsyncValue<bool> connected) {
    final bool isConnected = connected.valueOrNull == true;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                color: isConnected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.settingsGoogleDrive,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isConnected)
                _StatusChip(
                  label: context.l10n.settingsDriveConnected,
                  color: Theme.of(context).colorScheme.primary,
                )
              else
                _StatusChip(
                  label: context.l10n.settingsDriveDisconnected,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!isConnected)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _connectDrive,
                icon: const Icon(Icons.login_rounded),
                label: Text(context.l10n.settingsConnectDrive),
              ),
            )
          else
            Text(
              context.l10n.settingsBackupEncrypted,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _buildBackupAction(BackupUiState ui, bool canBackup) {
    if (ui.isBusy) {
      return SettingsCard(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ui.activity == BackupActivity.restoring
                    ? context.l10n.settingsBackupProgressRestoring
                    : context.l10n.settingsBackupProgressUploading,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(
                value: ui.progress.clamp(0.0, 1.0),
                minHeight: 10,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${(ui.progress * 100).round()}%',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ],
      );
    }

    return SettingsCard(
      children: [
        SettingsTile(
          icon: Icons.history_rounded,
          title: context.l10n.settingsLastBackup,
          subtitle: _lastBackupLabel(
            ref.read(settingsControllerProvider).valueOrNull?.lastBackupAt,
          ),
          showChevron: false,
          onTap: null,
          trailing: FilledButton.tonalIcon(
            onPressed: canBackup ? _backupNow : null,
            icon: const Icon(Icons.backup_rounded),
            label: Text(context.l10n.settingsBackupNow),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncStatusCard() {
    final SyncUiState sync = ref.watch(syncControllerProvider);
    final SyncQueueSnapshot? snapshot = sync.snapshot;

    final String status = sync.isSyncing
        ? context.l10n.settingsSyncInProgress
        : snapshot == null
        ? context.l10n.settingsSyncNever
        : snapshot.isClean
        ? context.l10n.settingsSyncHealthy
        : '${snapshot.pending + snapshot.failed} '
              '${context.l10n.settingsSyncPending}';

    return SettingsCard(
      children: [
        SettingsTile(
          icon: Icons.sync_rounded,
          title: context.l10n.settingsSyncStatus,
          subtitle: status,
          showChevron: false,
          trailing: FilledButton.tonalIcon(
            onPressed: sync.isSyncing
                ? null
                : () => ref.read(syncControllerProvider.notifier).runSync(),
            icon: Icon(
              sync.isSyncing ? Icons.sync_rounded : Icons.cloud_sync_rounded,
            ),
            label: Text(context.l10n.settingsSyncNow),
          ),
        ),
      ],
    );
  }

  Future<void> _connectDrive() async {
    final signIn = ref.read(googleSignInServiceProvider);
    try {
      await signIn.initialize();
      await signIn.authenticate();
      if (!mounted) return;
      ref.invalidate(driveConnectedProvider);
      ref.invalidate(remoteBackupsProvider);
    } catch (error) {
      if (error is AppException && error.code == 'cancelled') return;
      if (!mounted) return;
      AppSnackbar.error(
        context,
        localizeFailureMessage(
          context.l10n,
          error is AppException ? error.message : 'backupFailed',
        ),
      );
    }
  }

  Future<void> _backupNow() async {
    final controller = ref.read(backupControllerProvider.notifier);
    try {
      await controller.createBackup();
      if (mounted) {
        AppSnackbar.success(context, context.l10n.settingsBackupSuccess);
      }
    } on Exception {
      if (mounted) {
        final BackupUiState ui = ref.read(backupControllerProvider);
        AppSnackbar.error(
          context,
          localizeFailureMessage(context.l10n, ui.errorKey ?? 'backupFailed'),
        );
      }
    }
  }

  Future<void> _restoreBackup(RemoteBackupFile file) async {
    final controller = ref.read(backupControllerProvider.notifier);

    final BackupPreview preview;
    try {
      preview = await controller.previewBackup(file);
    } on Exception {
      if (mounted) {
        AppSnackbar.error(context, context.l10n.settingsRestoreFailed);
      }
      return;
    }
    if (!mounted) return;

    final settings = ref.read(settingsControllerProvider).valueOrNull;
    final BackupRestoreRisk risk = controller.restoreRisk(
      preview,
      lastBackupAt: settings?.lastBackupAt,
    );

    if (risk.isBlocked) {
      AppSnackbar.error(context, context.l10n.settingsRestoreBlockedNewer);
      return;
    }

    final bool? confirmed = await _showRestorePreview(preview, risk);
    if (confirmed != true || !mounted) return;

    try {
      await controller.restoreBackup(file);
      if (mounted) {
        await AppDialog.success(
          context: context,
          title: context.l10n.settingsRestoreSuccess,
        );
      }
    } on Exception {
      if (mounted) {
        final BackupUiState ui = ref.read(backupControllerProvider);
        AppSnackbar.error(
          context,
          localizeFailureMessage(context.l10n, ui.errorKey ?? 'backupFailed'),
        );
      }
    }
  }

  Future<bool?> _showRestorePreview(
    BackupPreview preview,
    BackupRestoreRisk risk,
  ) {
    final BackupMetadata metadata = preview.metadata;
    final String? warning = switch (risk) {
      BackupRestoreRisk.losesRecentData =>
        context.l10n.settingsRestoreWarningNewer,
      BackupRestoreRisk.fromOlderVersion =>
        context.l10n.settingsRestoreWarningOlder,
      _ => null,
    };

    return AppDialog.show<bool>(
      context: context,
      title: context.l10n.settingsRestoreBackup,
      barrierDismissible: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewRow(
            icon: Icons.schedule_rounded,
            label: context.l10n.settingsLastBackup,
            value: DateFormat('dd MMM yyyy, h:mm a').format(
              metadata.createdAt,
            ),
          ),
          if (metadata.rawSizeBytes != null)
            _PreviewRow(
              icon: Icons.data_usage_rounded,
              label: context.l10n.settingsBackupSize,
              value: _formatBytes(metadata.rawSizeBytes!),
            ),
          if (metadata.deviceName.isNotEmpty)
            _PreviewRow(
              icon: Icons.smartphone_rounded,
              label: context.l10n.settingsBackupDevice,
              value: metadata.deviceName,
            ),
          _PreviewRow(
            icon: Icons.lock_rounded,
            label: context.l10n.settingsBackupEncrypted,
            value: context.l10n.settingsDriveConnected,
          ),
          if (warning != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: AppRadius.mdRadius,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      warning,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.settingsRestoreConfirm,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.restore_rounded),
          label: Text(context.l10n.settingsRestoreBackup),
        ),
      ],
    );
  }

  Future<void> _deleteBackup(RemoteBackupFile file) async {
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: context.l10n.settingsDeleteBackup,
      message: context.l10n.settingsDeleteBackupConfirm,
      confirmLabel: context.l10n.settingsDeleteBackup,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(backupControllerProvider.notifier).deleteBackup(file);
      if (mounted) {
        AppSnackbar.success(context, context.l10n.settingsBackupDeleteSuccess);
      }
    } on Exception {
      if (mounted) {
        AppSnackbar.error(context, context.l10n.settingsRestoreFailed);
      }
    }
  }

  Future<void> _signOut() async {
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: context.l10n.settingsSignOutDrive,
      message: context.l10n.settingsSignOutDriveSubtitle,
      confirmLabel: context.l10n.settingsSignOutDrive,
      destructive: false,
    );
    if (confirmed != true || !mounted) return;
    await ref.read(backupControllerProvider.notifier).signOutFromDrive();
  }

  Future<void> _pickSchedule(
    SettingsController controller,
    AppSettings? settings,
  ) async {
    final BackupSchedule? selected = await showSettingsChoices<BackupSchedule>(
      context: context,
      title: context.l10n.settingsBackupSchedule,
      icon: Icons.schedule_rounded,
      current: settings?.backupSchedule ?? BackupSchedule.manual,
      choices: BackupSchedule.values
          .map(
            (BackupSchedule value) => SettingsChoice<BackupSchedule>(
              label: _scheduleLabel(context, value),
              value: value,
            ),
          )
          .toList(),
    );
    if (selected != null) {
      await controller.setBackupSchedule(selected);
    }
  }

  Future<void> _pickRetention(
    SettingsController controller,
    AppSettings? settings,
  ) async {
    final int? selected = await showSettingsChoices<int>(
      context: context,
      title: context.l10n.settingsBackupRetention,
      icon: Icons.layers_rounded,
      current: settings?.backupRetentionCount ?? 5,
      choices: List<SettingsChoice<int>>.generate(
        10,
        (int index) => SettingsChoice<int>(
          label: '${index + 1}',
          value: index + 1,
        ),
      ),
    );
    if (selected != null) {
      await controller.setBackupRetention(selected);
    }
  }

  String _scheduleLabel(BuildContext context, BackupSchedule schedule) {
    return switch (schedule) {
      BackupSchedule.manual => context.l10n.settingsScheduleManual,
      BackupSchedule.daily => context.l10n.settingsScheduleDaily,
      BackupSchedule.weekly => context.l10n.settingsScheduleWeekly,
      BackupSchedule.monthly => context.l10n.settingsScheduleMonthly,
    };
  }

  String _lastBackupLabel(DateTime? at) {
    if (at == null) return context.l10n.backupNever;
    return DateFormat('dd MMM yyyy, h:mm a').format(at);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _messageKeyOf(Object error) {
    if (error is AppException) return error.message;
    return 'backupFailed';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemoteBackupsList extends StatelessWidget {
  const _RemoteBackupsList({
    required this.files,
    required this.busy,
    required this.onRestore,
    required this.onDelete,
  });

  final List<RemoteBackupFile> files;
  final bool busy;
  final ValueChanged<RemoteBackupFile> onRestore;
  final ValueChanged<RemoteBackupFile> onDelete;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      children: [
        for (int index = 0; index < files.length; index++) ...[
          if (index > 0) const Divider(height: 1, indent: AppSpacing.xxl),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_rounded),
            title: Text(
              DateFormat('dd MMM yyyy, h:mm a').format(
                files[index].createdAt,
              ),
            ),
            subtitle: Text(_formatSize(context, files[index].sizeBytes)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: context.l10n.settingsRestoreBackup,
                  onPressed: busy ? null : () => onRestore(files[index]),
                  icon: const Icon(Icons.restore_rounded),
                ),
                IconButton(
                  tooltip: context.l10n.settingsDeleteBackup,
                  onPressed: busy ? null : () => onDelete(files[index]),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatSize(BuildContext context, int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _BackupHistoryList extends StatelessWidget {
  const _BackupHistoryList({required this.entries});

  final List<BackupHistory> entries;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      children: [
        for (int index = 0; index < entries.length; index++) ...[
          if (index > 0) const Divider(height: 1, indent: AppSpacing.xxl),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _historyIcon(context, entries[index]),
            title: Text(
              DateFormat('dd MMM yyyy, h:mm a').format(entries[index].createdAt),
            ),
            subtitle: Text(
              entries[index].backupType == BackupType.auto
                  ? context.l10n.settingsBackupAuto
                  : context.l10n.settingsBackupManual,
            ),
            trailing: Text(
              _historyStatus(context, entries[index].status),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: entries[index].status == BackupStatus.failed
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _historyIcon(BuildContext context, BackupHistory entry) {
    final IconData icon = switch (entry.status) {
      BackupStatus.success => Icons.check_circle_rounded,
      BackupStatus.failed => Icons.error_rounded,
      BackupStatus.inProgress => Icons.hourglass_top_rounded,
    };
    final Color color = switch (entry.status) {
      BackupStatus.success => Theme.of(context).colorScheme.primary,
      BackupStatus.failed => Theme.of(context).colorScheme.error,
      BackupStatus.inProgress =>
        Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Icon(icon, color: color);
  }

  String _historyStatus(BuildContext context, BackupStatus status) {
    return switch (status) {
      BackupStatus.success => context.l10n.settingsBackupStatusSuccess,
      BackupStatus.failed => context.l10n.settingsBackupStatusFailed,
      BackupStatus.inProgress => context.l10n.settingsBackupStatusInProgress,
    };
  }
}

class _EmptyBackupsCard extends StatelessWidget {
  const _EmptyBackupsCard({required this.connected, required this.onConnect});

  final bool connected;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Icon(
                Icons.cloud_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.l10n.settingsNoRemoteBackups,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (!connected) ...[
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonalIcon(
                  onPressed: onConnect,
                  icon: const Icon(Icons.login_rounded),
                  label: Text(context.l10n.settingsConnectDrive),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const SettingsCard(
      children: [
        Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        ),
      ],
    );
  }
}
