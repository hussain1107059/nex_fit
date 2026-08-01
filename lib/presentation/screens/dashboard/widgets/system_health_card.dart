import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../data/services/sync/sync_engine.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/system_health.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/system_health_provider.dart';
import '../../../providers/sync_providers.dart';
import '../../../router/app_router.dart';

/// Dashboard card summarising sync, security, database and backup health.
///
/// Each metric renders a small status row with a trailing action that deep
/// links into the matching settings screen. Tapping the card header opens the
/// backup & sync screen.
class SystemHealthCard extends ConsumerWidget {
  const SystemHealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings? settings =
        ref.watch(settingsControllerProvider).valueOrNull;
    final SyncUiState sync = ref.watch(syncControllerProvider);
    final AsyncValue<SystemHealth> healthAsync = ref.watch(
      systemHealthProvider,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
            alpha: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.monitor_heart_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.dashboardSystemHealth,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.settingsBackupRestore,
                onPressed: () => context.push(AppRoutes.settingsBackup),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _HealthRow(
            icon: Icons.sync_rounded,
            label: context.l10n.healthSync,
            healthy: !sync.isSyncing && (sync.snapshot?.isClean ?? true),
            detail: _syncDetail(context, sync),
            onTap: () => context.push(AppRoutes.settingsBackup),
          ),
          _HealthRow(
            icon: Icons.shield_rounded,
            label: context.l10n.healthSecurity,
            healthy:
                (settings?.encryptionEnabled ?? true) &&
                (settings?.appLockEnabled ?? false),
            detail: settings?.appLockEnabled ?? false
                ? context.l10n.healthSecurityLocked
                : context.l10n.healthSecurityOpen,
            onTap: () => context.push(AppRoutes.settingsSecurity),
          ),
          _HealthRow(
            icon: Icons.storage_rounded,
            label: context.l10n.healthDatabase,
            healthy: healthAsync.valueOrNull?.dbHealthy ?? true,
            detail: _databaseDetail(context, healthAsync.valueOrNull),
            onTap: () => context.push(AppRoutes.settingsStorage),
          ),
          _HealthRow(
            icon: Icons.cloud_rounded,
            label: context.l10n.healthBackup,
            healthy: healthAsync.valueOrNull?.backupConnected ?? false,
            detail: _backupDetail(context, healthAsync.valueOrNull),
            onTap: () => context.push(AppRoutes.settingsBackup),
          ),
        ],
      ),
    );
  }

  String _syncDetail(BuildContext context, SyncUiState sync) {
    final SyncQueueSnapshot? snapshot = sync.snapshot;
    if (sync.isSyncing) return context.l10n.settingsSyncInProgress;
    if (snapshot == null) return context.l10n.settingsSyncNever;
    if (!snapshot.isClean) {
      final int count = snapshot.pending + snapshot.failed;
      return '${context.l10n.settingsSyncPending}: $count';
    }
    final DateTime? last = snapshot.lastSyncedAt;
    return last == null
        ? context.l10n.settingsSyncNever
        : '${context.l10n.healthLastSync}: '
              '${DateFormat('dd MMM, h:mm a').format(last)}';
  }

  String _databaseDetail(BuildContext context, SystemHealth? health) {
    if (health == null) return '...';
    final String size = _formatBytes(health.databaseSizeBytes);
    return health.dbHealthy ? size : context.l10n.healthDatabaseError;
  }

  String _backupDetail(BuildContext context, SystemHealth? health) {
    if (health == null) return '...';
    if (!health.backupConnected) return context.l10n.settingsDriveDisconnected;
    final DateTime? last = health.lastBackupAt;
    return last == null
        ? context.l10n.backupNever
        : '${context.l10n.settingsLastBackup}: '
              '${DateFormat('dd MMM, h:mm a').format(last)}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.icon,
    required this.label,
    required this.healthy,
    required this.detail,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool healthy;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              healthy ? Icons.check_circle_rounded : Icons.error_rounded,
              size: 20,
              color: healthy
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
