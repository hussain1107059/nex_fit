import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/providers/sync_providers.dart';
import '../dashboard/widgets/system_health_card.dart';

/// System health overview (sync, security, database and backup) moved out of
/// the home dashboard into Settings.
class SystemHealthSettingsScreen extends ConsumerWidget {
  const SystemHealthSettingsScreen({super.key});

  Future<void> _confirmResync(BuildContext context, WidgetRef ref) async {
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
    if (confirmed != true) return;
    final String? userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    final SyncResetResult result =
        await ref.read(syncControllerProvider.notifier).resetAndResync();
    if (!context.mounted) return;
    final String message;
    if (result.success) {
      message = '${context.l10n.settingsResyncTitle} — '
          '${result.pulled} changes';
    } else if (result.error != null) {
      message = '${context.l10n.settingsResyncTitle} — '
          '${context.l10n.syncStatusFailed}';
    } else if (!result.deleted) {
      message = '${context.l10n.settingsResyncTitle} — '
          '${context.l10n.settingsSyncPending}';
    } else {
      message = context.l10n.settingsResyncTitle;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyncUiState sync = ref.watch(syncControllerProvider);
    final bool busy = sync.isSyncing || sync.isInitialSyncing;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dashboardSystemHealth)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          const SystemHealthCard(),
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.sync_problem_rounded),
              title: Text(context.l10n.settingsResyncTitle),
              subtitle: Text(context.l10n.settingsResyncDescription),
              trailing: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: busy ? null : () => _confirmResync(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}