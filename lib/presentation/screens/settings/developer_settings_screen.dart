import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs/app_dialog.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../domain/entities/app_settings.dart';
import '../../providers/settings_providers.dart';
import 'widgets/settings_widgets.dart';

/// Debug-only developer options. This screen is only reachable in debug
/// builds, so the tools here never ship to end users.
class DeveloperSettingsScreen extends ConsumerWidget {
  const DeveloperSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings? settings =
        ref.watch(settingsControllerProvider).valueOrNull;
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsDeveloper)),
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
