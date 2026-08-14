import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/common_enums.dart';
import '../../providers/settings_providers.dart';
import '../../router/app_router.dart';
import 'widgets/settings_widgets.dart';

/// Root of the Settings module. Groups every preference category into
/// navigable sections and exposes quick controls for the most common options.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings? settings =
        ref.watch(settingsControllerProvider).valueOrNull;
    final controller = ref.read(settingsControllerProvider.notifier);

    final String unitsLabel =
        settings?.units == Units.imperial
        ? context.l10n.settingsUnitsImperial
        : context.l10n.settingsUnitsMetric;
    final String weekStartLabel = settings?.weekStart == WeekStart.monday
        ? context.l10n.settingsWeekStartsMonday
        : context.l10n.settingsWeekStartsSunday;
    final String fontLabel = _fontLabel(context, settings?.fontScale);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          SettingsSectionTitle(context.l10n.settingsGeneral),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.person_outline_rounded,
                title: context.l10n.settingsEditProfile,
                onTap: () => context.push(AppRoutes.profileEdit),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.straighten_rounded,
                title: context.l10n.settingsUnits,
                value: unitsLabel,
                onTap: () async {
                  final Units? selected = await showSettingsChoices<Units>(
                    context: context,
                    title: context.l10n.settingsUnits,
                    icon: Icons.straighten_rounded,
                    current: settings?.units ?? Units.metric,
                    choices: [
                      SettingsChoice<Units>(
                        label: context.l10n.settingsUnitsMetric,
                        value: Units.metric,
                      ),
                      SettingsChoice<Units>(
                        label: context.l10n.settingsUnitsImperial,
                        value: Units.imperial,
                      ),
                    ],
                  );
                  if (selected != null) await controller.setUnits(selected);
                },
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.calendar_today_rounded,
                title: context.l10n.settingsWeekStart,
                value: weekStartLabel,
                onTap: () async {
                  final WeekStart? selected = await showSettingsChoices<WeekStart>(
                    context: context,
                    title: context.l10n.settingsWeekStart,
                    icon: Icons.calendar_today_rounded,
                    current: settings?.weekStart ?? WeekStart.sunday,
                    choices: [
                      SettingsChoice<WeekStart>(
                        label: context.l10n.settingsWeekStartsSunday,
                        value: WeekStart.sunday,
                      ),
                      SettingsChoice<WeekStart>(
                        label: context.l10n.settingsWeekStartsMonday,
                        value: WeekStart.monday,
                      ),
                    ],
                  );
                  if (selected != null) await controller.setWeekStart(selected);
                },
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsAppearance),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.format_size_rounded,
                title: context.l10n.settingsFontSize,
                value: fontLabel,
                onTap: () => context.push(AppRoutes.settingsAppearance),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsLanguage),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.language_rounded,
                title: context.l10n.settingsLanguage,
                value: context.l10n.editLanguageBangla,
                onTap: () => context.push(AppRoutes.settingsLanguage),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsNotifications),
          SettingsCard(
            children: [
              SettingsSwitchTile(
                icon: Icons.notifications_active_rounded,
                title: context.l10n.settingsNotifications,
                subtitle: context.l10n.settingsNotificationsMasterSubtitle,
                value: settings?.notificationsEnabled ?? true,
                onChanged: (bool value) =>
                    controller.setNotificationsEnabled(value),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.tune_rounded,
                title: context.l10n.settingsNotificationPreferences,
                onTap: () => context.push(AppRoutes.settingsNotifications),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsWorkout),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.fitness_center_rounded,
                title: context.l10n.settingsWorkout,
                subtitle: context.l10n.settingsWorkoutSubtitle,
                onTap: () => context.push(AppRoutes.settingsWorkout),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsNutrition),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.restaurant_rounded,
                title: context.l10n.settingsNutrition,
                subtitle: context.l10n.settingsNutritionSubtitle,
                onTap: () => context.push(AppRoutes.settingsNutrition),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsPrivacy),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.privacy_tip_rounded,
                title: context.l10n.settingsPrivacy,
                onTap: () => context.push(AppRoutes.settingsPrivacy),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsSecurity),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.shield_rounded,
                title: context.l10n.settingsSecurity,
                subtitle: context.l10n.settingsSecuritySubtitle,
                onTap: () => context.push(AppRoutes.settingsSecurity),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsStorage),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.storage_rounded,
                title: context.l10n.settingsStorage,
                onTap: () => context.push(AppRoutes.settingsStorage),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.syncSettingsTitle),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.sync_rounded,
                title: context.l10n.syncSettingsTitle,
                subtitle: context.l10n.settingsSyncStatus,
                onTap: () => context.push(AppRoutes.settingsSync),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsBackup),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.backup_rounded,
                title: context.l10n.settingsBackup,
                onTap: () => context.push(AppRoutes.settingsBackup),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsSupport),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.support_agent_rounded,
                title: context.l10n.settingsSupport,
                onTap: () => context.push(AppRoutes.settingsSupport),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsAbout),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.info_outline_rounded,
                title: context.l10n.settingsAbout,
                onTap: () => context.push(AppRoutes.settingsAbout),
              ),
            ],
          ),
          if (kDebugMode) ...[
            SettingsSectionTitle(context.l10n.settingsDeveloper),
            SettingsCard(
              children: [
                SettingsTile(
                  icon: Icons.code_rounded,
                  title: context.l10n.settingsDeveloper,
                  subtitle: context.l10n.settingsDeveloperSubtitle,
                  onTap: () => context.push(AppRoutes.settingsDeveloper),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fontLabel(BuildContext context, FontScale? scale) {
    return switch (scale ?? FontScale.medium) {
      FontScale.small => context.l10n.settingsFontSizeSmall,
      FontScale.medium => context.l10n.settingsFontSizeMedium,
      FontScale.large => context.l10n.settingsFontSizeLarge,
      FontScale.extraLarge => context.l10n.settingsFontSizeExtraLarge,
    };
  }
}
