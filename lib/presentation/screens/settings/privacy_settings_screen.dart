import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs/app_dialog.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../domain/entities/app_settings.dart';
import '../../providers/settings_providers.dart';
import 'widgets/settings_widgets.dart';

/// Privacy controls: hiding sensitive content from the app switcher and wiping
/// locally stored data.
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings? settings =
        ref.watch(settingsControllerProvider).valueOrNull;
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsPrivacy)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          SettingsSectionTitle(context.l10n.settingsPrivacySensitive),
          SettingsCard(
            children: [
              SettingsSwitchTile(
                icon: Icons.visibility_off_rounded,
                title: context.l10n.settingsHideRecentApps,
                subtitle: context.l10n.settingsHideRecentAppsSubtitle,
                value: settings?.hideRecentApps ?? false,
                onChanged: (bool value) =>
                    controller.setHideRecentApps(value),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsSwitchTile(
                icon: Icons.screenshot_rounded,
                title: context.l10n.settingsScreenshotLock,
                subtitle: context.l10n.settingsScreenshotLockSubtitle,
                value: settings?.screenshotLock ?? false,
                onChanged: (bool value) =>
                    controller.setScreenshotLock(value),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsDangerZone),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.delete_forever_rounded,
                title: context.l10n.settingsDeleteLocalData,
                subtitle: context.l10n.settingsDeleteLocalDataSubtitle,
                destructive: true,
                onTap: () => _confirmDeleteLocalData(context, controller),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteLocalData(
    BuildContext context,
    SettingsController controller,
  ) async {
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: context.l10n.settingsDeleteLocalData,
      message: context.l10n.settingsDeleteLocalDataConfirm,
      confirmLabel: context.l10n.settingsDeleteLocalDataAction,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    await controller.deleteLocalData();
    if (context.mounted) {
      AppSnackbar.success(context, context.l10n.settingsDeleteLocalDataDone);
    }
  }
}
