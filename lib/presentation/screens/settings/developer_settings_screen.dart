import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs/app_dialog.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../data/datasources/local/master_catalog_state_local_data_source.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/security_enums.dart';
import '../../../domain/entities/sync_conflict_record.dart';
import '../../../domain/entities/sync_event.dart';
import '../../../domain/entities/sync_state.dart';
import '../../../injection/dependency_injection.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/settings_providers.dart';
import '../../../presentation/providers/sync_providers.dart';
import 'widgets/settings_widgets.dart';

/// Debug-only developer options. This screen is only reachable in debug
/// builds, so the tools here never ship to end users.
class DeveloperSettingsScreen extends ConsumerStatefulWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  ConsumerState<DeveloperSettingsScreen> createState() =>
      _DeveloperSettingsScreenState();
}

class _DeveloperSettingsScreenState
    extends ConsumerState<DeveloperSettingsScreen> {
  int _diagRefresh = 0;

  void _reloadDiagnostics() {
    setState(() => _diagRefresh++);
  }

  Future<void> _copyDiagnostics(BuildContext context, String? userId) async {
    if (userId == null) {
      AppSnackbar.info(context, 'Sign in first to read diagnostics.');
      return;
    }
    final repo = ref.read(syncEventRepositoryProvider);
    final conflictRepo = ref.read(syncConflictRepositoryProvider);
    final masterRepo = ref.read(masterCatalogStateLocalDataSourceProvider);
    final List<SyncEvent> events =
        await repo.getNonCompletedByUserId(userId, limit: 100);
    final List<SyncConflictRecord> conflicts =
        await conflictRepo.getPending(userId);
    final List<MasterCatalogState> masters = await masterRepo.getAll();

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('--- NexFit sync diagnostics ---');
    buffer.writeln('user: $userId');
    buffer.writeln('at: ${DateTime.now().toIso8601String()}');

    SyncState? syncState;
    try {
      syncState = await ref
          .read(syncStateRepositoryProvider)
          .getByUserId(userId);
    } catch (_) {
      syncState = null;
    }
    buffer.writeln();
    buffer.writeln('SYNC STATE:');
    if (syncState == null) {
      buffer.writeln('- no sync_state row (never pulled)');
    } else {
      buffer.writeln(
        '- cursor=${syncState.cursor} '
        'initialSyncCompleted=${syncState.initialSyncCompleted} '
        'status=${syncState.status ?? 'null'}',
      );
      buffer.writeln(
        '- lastSyncAt=${syncState.lastSyncAt?.toIso8601String() ?? 'null'} '
        'updatedAt=${syncState.updatedAt.toIso8601String()}',
      );
    }

    final SyncUiState syncUi = ref.read(syncControllerProvider);
    buffer.writeln();
    buffer.writeln('LAST FULL RE-SYNC:');
    if (syncUi.resetAt == null) {
      buffer.writeln('- none yet');
    } else {
      buffer.writeln(
        '- at=${syncUi.resetAt!.toIso8601String()} '
        'pulled=${syncUi.resetPulled} '
        'error=${syncUi.resetError ?? 'null'}',
      );
      if (syncUi.resetTables != null && syncUi.resetTables!.isNotEmpty) {
        buffer.writeln('  applied: ${syncUi.resetTables}');
      }
    }

    try {
      final db = await ref.read(appDatabaseProvider).database;
      final List<Map<String, Object?>> workouts = await db.query(
        'workout_history',
        where: 'user_id = ?',
        whereArgs: <Object?>[userId],
        orderBy: 'started_at DESC',
        limit: 5,
      );
      buffer.writeln();
      buffer.writeln('LOCAL WORKOUT_HISTORY (${workouts.length}):');
      for (final Map<String, Object?> row in workouts) {
        buffer.writeln(
          '- id=${row['id']} is_completed=${row['is_completed']} '
          'calories=${row['calories_burn']} deleted_at=${row['deleted_at']} '
          'started=${row['started_at']} ended=${row['ended_at']} '
          'version=${row['row_version']} workout_id=${row['workout_id']} '
          'uuid=${row['uuid']}',
        );
      }
    } catch (_) {
      buffer.writeln();
      buffer.writeln('LOCAL WORKOUT_HISTORY: (query failed)');
    }
    buffer.writeln();
    buffer.writeln('EVENTS (${events.length} not completed):');
    for (final SyncEvent event in events) {
      buffer.writeln(
        '- ${event.entity}#${event.entityId} ${event.operation.name} '
        '[${event.status.name}] retry=${event.retryCount} '
        'baseV=${event.baseVersion} created=${event.createdAt.toIso8601String()}',
      );
      if (event.lastError != null && event.lastError!.isNotEmpty) {
        buffer.writeln('  error: ${event.lastError}');
      }
    }
    buffer.writeln();
    buffer.writeln('PENDING CONFLICTS (${conflicts.length}):');
    for (final SyncConflictRecord conflict in conflicts) {
      buffer.writeln(
        '- ${conflict.entity} ${conflict.recordUuid} ${conflict.status.name}',
      );
    }
    buffer.writeln();
    buffer.writeln('MASTER DATA (${masters.length} catalogs):');
    for (final MasterCatalogState state in masters) {
      buffer.writeln(
        '- ${state.catalog} v${state.dataVersion} ${state.status}',
      );
      if (state.lastError != null && state.lastError!.isNotEmpty) {
        buffer.writeln('  error: ${state.lastError}');
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (context.mounted) {
      AppSnackbar.success(context, 'Diagnostics copied.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings? settings =
        ref.watch(settingsControllerProvider).valueOrNull;
    final controller = ref.read(settingsControllerProvider.notifier);
    final String? userId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsDeveloper),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy diagnostics',
            onPressed: () => _copyDiagnostics(context, userId),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload diagnostics',
            onPressed: _reloadDiagnostics,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          SettingsSectionTitle(context.l10n.settingsDeveloperLogging),
          SettingsCard(
            children: [
              SettingsSwitchTile(
                icon: Icons.bug_report_rounded,
                title: context.l10n.settingsDebugLogging,
                subtitle: context.l10n.settingsDebugLoggingSubtitle,
                value: settings?.logsEnabled ?? false,
                onChanged: (bool value) => controller.setLogsEnabled(value),
              ),
            ],
          ),
          if (userId != null) ...[
            SettingsSectionTitle('Sync diagnostics'),
            _SyncDiagnosticsCard(
              userId: userId,
              refreshKey: _diagRefresh,
              onChanged: _reloadDiagnostics,
            ),
            SettingsCard(
              children: [
                ListTile(
                  leading: const Icon(Icons.sync_problem_rounded),
                  title: Text(context.l10n.settingsResyncTitle),
                  subtitle: Text(context.l10n.settingsResyncDescription),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _confirmResync(context, ref),
                ),
              ],
            ),
          ],
          SettingsSectionTitle(context.l10n.settingsDeveloperInfo),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.storage_rounded,
                title: context.l10n.settingsDbVersion,
                value: AppConstants.databaseVersion.toString(),
                showChevron: false,
                onTap: null,
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.flutter_dash_rounded,
                title: 'Flutter',
                value: '3.12.2',
                showChevron: false,
                onTap: null,
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsDeveloperReset),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.restart_alt_rounded,
                title: context.l10n.settingsResetAll,
                subtitle: context.l10n.settingsResetAllSubtitle,
                destructive: true,
                onTap: () => _confirmReset(context, controller),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmResync(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(context.l10n.settingsResyncTitle),
        content: Text(context.l10n.settingsResyncConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final String? userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    final SyncResetResult result =
        await ref.read(syncControllerProvider.notifier).resetAndResync();
    if (!context.mounted) return;
    final String message;
    if (result.success) {
      message = '${context.l10n.settingsResyncTitle} — '
          '${result.pulled} changes';
    } else {
      message = '${context.l10n.settingsResyncTitle} — '
          '${context.l10n.syncStatusFailed}';
    }
    AppSnackbar.success(context, message);
  }

  Future<void> _confirmReset(
    BuildContext context,
    SettingsController controller,
  ) async {
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: context.l10n.settingsResetAll,
      message: context.l10n.settingsResetAllConfirm,
      confirmLabel: context.l10n.settingsResetAllAction,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    await controller.resetSettings();
    if (context.mounted) {
      AppSnackbar.success(context, context.l10n.settingsResetAllDone);
    }
  }
}

/// Lists every outbox event that has not reached a final state plus unresolved
/// conflict records and the master-catalog watermark state, so stuck syncs can
/// be diagnosed from the device. Also exposes a developer recovery action that
/// re-queues all non-final events for a retry.
class _SyncDiagnosticsCard extends ConsumerWidget {
  const _SyncDiagnosticsCard({
    required this.userId,
    required this.refreshKey,
    required this.onChanged,
  });

  final String userId;
  final int refreshKey;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Future<List<SyncEvent>> events = Future.microtask(
      () => ref
          .read(syncEventRepositoryProvider)
          .getNonCompletedByUserId(userId, limit: 100),
    );
    final Future<List<SyncConflictRecord>> conflicts = Future.microtask(
      () => ref.read(syncConflictRepositoryProvider).getPending(userId),
    );
    final Future<List<MasterCatalogState>> masterStates = Future.microtask(
      () => ref.read(masterCatalogStateLocalDataSourceProvider).getAll(),
    );

    Future<void> requeue() async {
      await ref
          .read(syncEventRepositoryProvider)
          .requeueAllByUserId(userId, at: DateTime.now());
      onChanged();
    }

    return FutureBuilder<List<SyncEvent>>(
      key: ValueKey<String>('events-$refreshKey'),
      future: events,
      builder: (context, snapshot) {
        final List<SyncEvent> eventsList = snapshot.data ?? const <SyncEvent>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${eventsList.length} event(s) not completed',
                          style: context.textTheme.titleSmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: requeue,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Re-queue failed'),
                      ),
                    ],
                  ),
                ),
                if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Load error: ${snapshot.error}',
                      style: context.textTheme.bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (eventsList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('Queue is clean.'),
                  )
                else
                  for (final SyncEvent event in eventsList)
                    _EventRow(event: event),
                const Divider(height: 1),
                FutureBuilder<List<SyncConflictRecord>>(
                  future: conflicts,
                  builder: (context, conflictSnapshot) {
                    final List<SyncConflictRecord> pending =
                        conflictSnapshot.data ?? const <SyncConflictRecord>[];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        pending.isEmpty
                            ? 'No pending conflicts.'
                            : '${pending.length} pending conflict(s): '
                                '${pending.map((c) => c.entity).join(', ')}',
                        style: context.textTheme.bodySmall,
                      ),
                    );
                  },
                ),
              ],
            ),
            FutureBuilder<List<MasterCatalogState>>(
              key: ValueKey<String>('master-$refreshKey'),
              future: masterStates,
              builder: (context, masterSnapshot) {
                final List<MasterCatalogState> states =
                    masterSnapshot.data ?? const <MasterCatalogState>[];
                return SettingsCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Text(
                        'Master data: ${states.length} catalog(s)',
                        style: context.textTheme.titleSmall,
                      ),
                    ),
                    if (states.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Text('No catalog state recorded.'),
                      )
                    else
                      for (final MasterCatalogState state in states)
                        _MasterStateRow(state: state),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _MasterStateRow extends StatelessWidget {
  const _MasterStateRow({required this.state});

  final MasterCatalogState state;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool failed = state.status == 'failed';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  state.catalog,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'v${state.dataVersion} ${state.status}',
                style: context.textTheme.labelSmall?.copyWith(
                  color: failed ? scheme.error : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (state.lastError != null)
            Text(
              'error: ${state.lastError}',
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final SyncEvent event;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String statusLabel = event.status.name;
    final Color statusColor = switch (event.status) {
      SyncStatus.pending => Colors.orange.shade800,
      SyncStatus.failedRetryable => Colors.amber.shade800,
      SyncStatus.processing => scheme.primary,
      _ => scheme.error,
    };
    final String error = event.lastError ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${event.entity} #${event.entityId} '
                  '${event.operation.name}',
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'retry=${event.retryCount} baseV=${event.baseVersion} '
            'created=${_format(event.createdAt)}',
            style: context.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (error.isNotEmpty)
            Text(
              'error: $error',
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }

  static String _format(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}
