import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../data/services/sync/sync_engine.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/common_enums.dart';
import '../../../injection/dependency_injection.dart';
import '../../providers/settings_providers.dart';
import '../../providers/sync_providers.dart';
import '../../router/app_router.dart';
import 'widgets/settings_widgets.dart';

/// App lock, PIN/biometric unlock, session timeout, encryption and database
/// maintenance.
class SecuritySettingsScreen extends ConsumerWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings? settings =
        ref.watch(settingsControllerProvider).valueOrNull;
    final SettingsController controller =
        ref.read(settingsControllerProvider.notifier);
    final bool biometricAvailable =
        ref.watch(biometricAvailableProvider).valueOrNull ?? false;
    final bool appLock = settings?.appLockEnabled ?? false;
    final AutoLockDelay autoLock = settings?.autoLock ?? AutoLockDelay.minutes1;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsSecurity)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          SettingsSectionTitle(context.l10n.settingsAppLock),
          SettingsCard(
            children: [
              SettingsSwitchTile(
                icon: Icons.lock_outline_rounded,
                title: context.l10n.settingsAppLock,
                subtitle: context.l10n.settingsAppLockSubtitle,
                value: appLock,
                onChanged: (bool value) =>
                    _toggleAppLock(context, controller, value),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.password_rounded,
                title: context.l10n.settingsChangePin,
                enabled: controller.hasPin(),
                onTap: () => context.push<bool>(
                  AppRoutes.settingsPinSetup,
                  extra: true,
                ),
              ),
            ],
          ),
          if (biometricAvailable) ...[
            SettingsSectionTitle(context.l10n.settingsBiometric),
            SettingsCard(
              children: [
                SettingsSwitchTile(
                  icon: Icons.fingerprint_rounded,
                  title: context.l10n.settingsBiometricUnlock,
                  subtitle: context.l10n.settingsBiometricSubtitle,
                  value: settings?.biometricEnabled ?? false,
                  enabled: appLock,
                  onChanged: (bool value) =>
                      controller.setBiometricEnabled(value),
                ),
              ],
            ),
          ],
          SettingsSectionTitle(context.l10n.settingsAutoLock),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.timer_rounded,
                title: context.l10n.settingsAutoLock,
                value: _autoLockLabel(context, autoLock),
                onTap: () async {
                  final AutoLockDelay? selected =
                      await showSettingsChoices<AutoLockDelay>(
                        context: context,
                        title: context.l10n.settingsAutoLock,
                        icon: Icons.timer_rounded,
                        current: autoLock,
                        choices: AutoLockDelay.values
                            .map(
                              (AutoLockDelay delay) => SettingsChoice<
                                AutoLockDelay
                              >(
                                label: _autoLockLabel(context, delay),
                                value: delay,
                              ),
                            )
                            .toList(),
                      );
                  if (selected != null) {
                    await controller.setAutoLock(selected);
                  }
                },
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.hourglass_bottom_rounded,
                title: context.l10n.settingsSessionTimeout,
                value: _sessionTimeoutLabel(
                  context,
                  settings?.sessionTimeoutMinutes ?? 30,
                ),
                onTap: () async {
                  final int? selected = await showSettingsChoices<int>(
                    context: context,
                    title: context.l10n.settingsSessionTimeout,
                    icon: Icons.hourglass_bottom_rounded,
                    current: settings?.sessionTimeoutMinutes ?? 30,
                    choices: const <int>[5, 15, 30, 60, 120, 240]
                        .map(
                          (int minutes) => SettingsChoice<int>(
                            label: _sessionTimeoutLabel(context, minutes),
                            value: minutes,
                          ),
                        )
                        .toList(),
                  );
                  if (selected != null) {
                    await controller.setSessionTimeout(selected);
                  }
                },
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsEncryption),
          SettingsCard(
            children: [
              SettingsSwitchTile(
                icon: Icons.enhanced_encryption_rounded,
                title: context.l10n.settingsEncryption,
                subtitle: context.l10n.settingsEncryptionSubtitle,
                value: settings?.encryptionEnabled ?? true,
                onChanged: (bool value) =>
                    controller.setEncryptionEnabled(value),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsSyncStatus),
          SettingsCard(
            children: [
              const _SyncStatusTile(),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.cleaning_services_rounded,
                title: context.l10n.settingsRunOptimization,
                subtitle: context.l10n.settingsRunOptimizationSubtitle,
                onTap: () => _runOptimization(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAppLock(
    BuildContext context,
    SettingsController controller,
    bool value,
  ) async {
    if (value && !controller.hasPin()) {
      final bool? ok = await context.push<bool>(
        AppRoutes.settingsPinSetup,
        extra: false,
      );
      if (ok != true || !context.mounted) return;
    }
    await controller.setAppLockEnabled(value);
  }

  Future<void> _runOptimization(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await ref
          .read(databaseOptimizerServiceProvider)
          .runMaintenance();
      if (context.mounted) {
        AppSnackbar.success(context, context.l10n.settingsOptimizationDone);
        ref.invalidate(databaseSizeProvider);
        ref.invalidate(imageCacheSizeProvider);
      }
    } on Exception {
      if (context.mounted) {
        AppSnackbar.error(context, context.l10n.errorUnknown);
      }
    }
  }

  String _autoLockLabel(BuildContext context, AutoLockDelay delay) {
    return switch (delay) {
      AutoLockDelay.immediately => context.l10n.settingsAutoLockImmediately,
      AutoLockDelay.minutes1 => context.l10n.settingsAutoLockMinutes1,
      AutoLockDelay.minutes5 => context.l10n.settingsAutoLockMinutes5,
      AutoLockDelay.minutes15 => context.l10n.settingsAutoLockMinutes15,
      AutoLockDelay.minutes30 => context.l10n.settingsAutoLockMinutes30,
    };
  }

  String _sessionTimeoutLabel(BuildContext context, int minutes) {
    return minutes >= 60
        ? context.l10n.settingsSessionTimeoutHours(minutes ~/ 60)
        : context.l10n.settingsSessionTimeoutMinutes(minutes);
  }
}

/// Shows the pending/failed sync queue counts with a "Sync now" action.
class _SyncStatusTile extends ConsumerWidget {
  const _SyncStatusTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SyncUiState sync = ref.watch(syncControllerProvider);
    final SyncQueueSnapshot? snapshot = sync.snapshot;

    final String subtitle = sync.isSyncing
        ? context.l10n.settingsSyncInProgress
        : snapshot == null
        ? context.l10n.settingsSyncNever
        : snapshot.isClean
        ? context.l10n.settingsSyncHealthy
        : '${context.l10n.settingsSyncPending}: '
              '${snapshot.pending + snapshot.failed}';

    return SettingsTile(
      icon: Icons.sync_rounded,
      title: context.l10n.settingsSyncStatus,
      subtitle: subtitle,
      onTap: () async {
        ref.read(syncControllerProvider.notifier).runSync();
      },
    );
  }
}

