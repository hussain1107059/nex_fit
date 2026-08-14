import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../injection/dependency_injection.dart';
import '../../providers/settings_providers.dart';
import '../../providers/sync_providers.dart';
import '../../widgets/sync/sync_status_chip.dart';
import 'widgets/settings_widgets.dart';

/// Sync status + manual sync screen (PROMPT 22).
///
/// Shows a status chip, last-sync time, pending/failed change counts, conflict
/// count and a "Sync now" action. It never surfaces technical error text,
/// tokens or stack traces — only the friendly chip states and localised
/// completion/offline/failure notices.
class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  bool _manualRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(syncControllerProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Completion feedback for runs started from this screen.
    ref.listen<SyncUiState>(syncControllerProvider, (SyncUiState? previous, SyncUiState next) {
      if (!_manualRequested) return;
      if ((previous?.isSyncing ?? false) && !next.isSyncing) {
        _manualRequested = false;
        _reportCompletion(next);
      }
    });

    final SyncStatusSnapshot snapshot = ref.watch(syncStatusProvider);
    final SyncUiState sync = ref.watch(syncControllerProvider);
    final AppSettings? settings =
        ref.watch(settingsControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.syncSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          Center(
            child: SyncStatusChip(status: snapshot.status),
          ),
          const SizedBox(height: AppSpacing.md),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.history_rounded,
                title: context.l10n.syncSettingsLastSynced,
                value: _lastSyncedLabel(settings, snapshot),
                showChevron: false,
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.pending_actions_rounded,
                title: context.l10n.syncSettingsPendingChanges,
                value: '${snapshot.pendingCount}',
                showChevron: false,
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.error_outline_rounded,
                title: context.l10n.syncSettingsFailedChanges,
                value: '${snapshot.failedCount}',
                showChevron: false,
                destructive: snapshot.failedCount > 0,
              ),
              if (snapshot.pendingConflictCount > 0) ...[
                const Divider(height: 1, indent: AppSpacing.xxl),
                SettingsTile(
                  icon: Icons.warning_amber_rounded,
                  title: context.l10n.syncSettingsConflicts,
                  value: '${snapshot.pendingConflictCount}',
                  showChevron: false,
                  iconColor: Colors.amber.shade800,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: sync.isSyncing
                ? null
                : () {
                    _manualRequested = true;
                    ref.read(syncControllerProvider.notifier).runSync();
                  },
            icon: Icon(
              sync.isSyncing ? Icons.sync_rounded : Icons.cloud_sync_rounded,
            ),
            label: Text(
              sync.isSyncing
                  ? context.l10n.settingsSyncInProgress
                  : context.l10n.settingsSyncNow,
            ),
          ),
        ],
      ),
    );
  }

  String _lastSyncedLabel(
    AppSettings? settings,
    SyncStatusSnapshot snapshot,
  ) {
    final DateTime? last = settings?.lastSyncAt ?? snapshot.lastSyncAt;
    if (last == null) return context.l10n.syncSettingsNeverSynced;
    return DateFormat('dd MMM, h:mm a').format(last);
  }

  void _reportCompletion(SyncUiState next) {
    if (!mounted) return;
    final bool offline = !ref.read(supabaseSyncTransportProvider).isReady;
    if (next.failure != null) {
      AppSnackbar.error(context, context.l10n.syncCompletedWithErrors);
    } else if (offline) {
      AppSnackbar.info(context, context.l10n.syncCompletedOffline);
    } else {
      AppSnackbar.success(context, context.l10n.syncCompleted);
    }
  }
}