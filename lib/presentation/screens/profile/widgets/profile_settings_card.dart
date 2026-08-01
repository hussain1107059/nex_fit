import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../core/widgets/dialogs/app_dialog.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../domain/repositories/app_preferences_repository.dart';
import '../../../../injection/dependency_injection.dart';
import '../../../providers/auth_controller.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/profile_providers.dart';
import '../../../router/app_router.dart';
import 'profile_section_card.dart';

/// Settings shortcuts: dark mode, language, notifications, backup & restore,
/// about and logout.
class ProfileSettingsCard extends ConsumerWidget {
  const ProfileSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final bool notificationsEnabled =
        ref.watch(profileSettingsProvider).valueOrNull?.notificationsEnabled ??
        true;

    return ProfileSectionCard(
      title: context.l10n.commonSettings,
      icon: Icons.settings_rounded,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.settings_rounded,
            title: context.l10n.settingsAllSettings,
            onTap: () => context.push(AppRoutes.settings),
          ),
          const Divider(height: 1, indent: AppSpacing.xxl),
          _SwitchTile(
            icon: Icons.dark_mode_rounded,
            title: context.l10n.settingsDarkMode,
            value: themeMode == ThemeMode.dark,
            onChanged: (bool value) {
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
            },
          ),
          _SettingsTile(
            icon: Icons.language_rounded,
            title: context.l10n.settingsLanguage,
            onTap: () => _showLanguageSheet(context, ref),
          ),
          _SwitchTile(
            icon: Icons.notifications_rounded,
            title: context.l10n.settingsNotifications,
            value: notificationsEnabled,
            onChanged: (bool value) =>
                ref.read(profileSettingsProvider.notifier).toggleNotifications(value),
          ),
          _SettingsTile(
            icon: Icons.backup_rounded,
            title: context.l10n.settingsBackupRestore,
            onTap: () => _showBackupSheet(context, ref),
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: context.l10n.settingsAbout,
            onTap: () => _showAboutDialog(context),
          ),
          const Divider(height: 1, indent: AppSpacing.xxl),
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: context.l10n.settingsLogout,
            iconColor: context.colorScheme.error,
            titleColor: context.colorScheme.error,
            showChevron: false,
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguageSheet(BuildContext context, WidgetRef ref) async {
    final Locale current = ref.watch(localeProvider);
    final String? code = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _LanguageSheet(currentCode: current.languageCode);
      },
    );
    if (code == null || !context.mounted) return;
    await ref.read(localeProvider.notifier).setLocale(Locale(code));
  }

  Future<void> _showBackupSheet(BuildContext context, WidgetRef ref) async {
    final AppPreferencesRepository preferences =
        ref.read(appPreferencesRepositoryProvider);
    final DateTime? lastBackup = preferences.getLastBackupTime();
    final String lastLabel = lastBackup == null
        ? context.l10n.settingsNever
        : '${lastBackup.day}/${lastBackup.month}/${lastBackup.year}';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: sheetContext.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.settingsBackupRestore,
                    style: sheetContext.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.schedule_rounded,
                      color: sheetContext.colorScheme.primary,
                    ),
                    title: Text(context.l10n.settingsLastBackup),
                    subtitle: Text(lastLabel),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.l10n.settingsComingSoon,
                    textAlign: TextAlign.center,
                    style: sheetContext.textTheme.bodySmall?.copyWith(
                      color: sheetContext.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    await AppDialog.show(
      context: context,
      title: context.l10n.settingsAboutTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.settingsAboutMessage),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${context.l10n.settingsAboutVersion} ${AppConstants.appName}',
                style: context.textTheme.labelMedium,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonOk),
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: context.l10n.authSignOutConfirmTitle,
      message: context.l10n.authSignOutConfirmMessage,
      confirmLabel: context.l10n.authSignOut,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref.read(authControllerProvider.notifier).signOut();
    if (result.isFailure && context.mounted) {
      AppSnackbar.error(context, context.l10n.commonError);
    }
  }
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.currentCode});

  final String currentCode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final List<({String code, String label})> options = [
      (code: 'bn', label: l10n.editLanguageBangla),
      (code: 'en', label: l10n.editLanguageEnglish),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.settingsLanguage,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final option in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.language_rounded,
                  color: context.colorScheme.primary,
                ),
                title: Text(
                  option.label,
                  style: TextStyle(
                    fontWeight: currentCode == option.code
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
                trailing: currentCode == option.code
                    ? Icon(
                        Icons.check_rounded,
                        color: context.colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(option.code),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.titleColor,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
      ),
      leading: Icon(icon, color: iconColor ?? context.colorScheme.primary),
      title: Text(
        title,
        style: context.textTheme.bodyLarge?.copyWith(
          color: titleColor ?? context.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: showChevron
          ? Icon(
              Icons.chevron_right_rounded,
              color: context.colorScheme.onSurfaceVariant,
            )
          : null,
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
      ),
      secondary: Icon(icon, color: context.colorScheme.primary),
      title: Text(
        title,
        style: context.textTheme.bodyLarge?.copyWith(
          color: context.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
