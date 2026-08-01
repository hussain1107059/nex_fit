import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/common_enums.dart';
import '../../providers/settings_providers.dart';
import 'widgets/settings_widgets.dart';

/// Theme, dynamic color and font-size controls.
class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings? settings =
        ref.watch(settingsControllerProvider).valueOrNull;
    final controller = ref.read(settingsControllerProvider.notifier);
    final AppThemeMode themeMode = settings?.themeMode ?? AppThemeMode.system;
    final FontScale fontScale = settings?.fontScale ?? FontScale.medium;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsAppearance)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          SettingsSectionTitle(context.l10n.settingsTheme),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.brightness_auto_rounded,
                title: context.l10n.settingsThemeSystem,
                selected: themeMode == AppThemeMode.system,
                onTap: () => controller.setThemeMode(AppThemeMode.system),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.light_mode_rounded,
                title: context.l10n.settingsThemeLight,
                selected: themeMode == AppThemeMode.light,
                onTap: () => controller.setThemeMode(AppThemeMode.light),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.dark_mode_rounded,
                title: context.l10n.settingsThemeDark,
                selected: themeMode == AppThemeMode.dark,
                onTap: () => controller.setThemeMode(AppThemeMode.dark),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.phone_iphone_rounded,
                title: context.l10n.settingsThemeAmoled,
                subtitle: context.l10n.settingsThemeAmoledSubtitle,
                selected: themeMode == AppThemeMode.amoled,
                onTap: () => controller.setThemeMode(AppThemeMode.amoled),
              ),
            ],
          ),
          AppSpacing.sm.heightSpace,
          SettingsCard(
            children: [
              SettingsSwitchTile(
                icon: Icons.dynamic_feed_rounded,
                title: context.l10n.settingsDynamicColor,
                subtitle: context.l10n.settingsDynamicColorSubtitle,
                value: settings?.dynamicColor ?? false,
                onChanged: (bool value) => controller.setDynamicColor(value),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsFontSize),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.format_size_rounded,
                title: context.l10n.settingsFontSizeSmall,
                selected: fontScale == FontScale.small,
                onTap: () => controller.setFontScale(FontScale.small),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.format_size_rounded,
                title: context.l10n.settingsFontSizeMedium,
                selected: fontScale == FontScale.medium,
                onTap: () => controller.setFontScale(FontScale.medium),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.format_size_rounded,
                title: context.l10n.settingsFontSizeLarge,
                selected: fontScale == FontScale.large,
                onTap: () => controller.setFontScale(FontScale.large),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.format_size_rounded,
                title: context.l10n.settingsFontSizeExtraLarge,
                selected: fontScale == FontScale.extraLarge,
                onTap: () => controller.setFontScale(FontScale.extraLarge),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
