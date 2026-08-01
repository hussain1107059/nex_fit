import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs/app_dialog.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../injection/dependency_injection.dart';
import '../../providers/settings_providers.dart';
import 'widgets/settings_widgets.dart';

/// Local backup: schedules automatic exports, shows the last one and offers a
/// manual export of the whole database.
class BackupSettingsScreen extends ConsumerWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings? settings =
        ref.watch(settingsControllerProvider).valueOrNull;
    final controller = ref.read(settingsControllerProvider.notifier);
    final String lastBackup = settings?.lastBackupAt == null
        ? context.l10n.settingsNever
        : DateFormat(
            'dd MMM yyyy, h:mm a',
          ).format(settings!.lastBackupAt!);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsBackup)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          SettingsSectionTitle(context.l10n.settingsBackup),
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
              SettingsSwitchTile(
                icon: Icons.sync_rounded,
                title: context.l10n.settingsDataSync,
                subtitle: context.l10n.settingsDataSyncSubtitle,
                value: settings?.dataSyncEnabled ?? true,
                onChanged: (bool value) => controller.setDataSyncEnabled(value),
              ),
            ],
          ),
          AppSpacing.sm.heightSpace,
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.history_rounded,
                title: context.l10n.settingsLastBackup,
                value: lastBackup,
                showChevron: false,
                onTap: null,
              ),
            ],
          ),
          AppSpacing.lg.heightSpace,
          FilledButton.icon(
            onPressed: () => _backupNow(context, ref),
            icon: const Icon(Icons.save_alt_rounded),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(context.l10n.settingsBackupNow),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _backupNow(BuildContext context, WidgetRef ref) async {
    final String? path = await ref
        .read(settingsStorageServiceProvider)
        .exportDatabase();
    final controller = ref.read(settingsControllerProvider.notifier);
    if (path == null) {
      if (context.mounted) {
        AppSnackbar.error(context, context.l10n.settingsBackupFailed);
      }
      return;
    }
    await controller.setLastBackupAt(DateTime.now());
    if (context.mounted) {
      await AppDialog.success(
        context: context,
        title: context.l10n.settingsBackupSuccess,
        message: context.l10n.settingsBackupSuccessMessage,
      );
    }
  }
}
