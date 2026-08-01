import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_settings.dart';
import '../../providers/settings_providers.dart';
import 'widgets/settings_widgets.dart';

/// Notification behaviour: master switch, sound/vibration and which reminder
/// categories are turned on by default.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings? settings =
        ref.watch(settingsControllerProvider).valueOrNull;
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsNotifications)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
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
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsNotificationBehaviour),
          SettingsCard(
            children: [
              SettingsSwitchTile(
                icon: Icons.volume_up_rounded,
                title: context.l10n.settingsNotificationSound,
                value: settings?.notificationSound ?? true,
                onChanged: (bool value) =>
                    controller.setNotificationSound(value),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsSwitchTile(
                icon: Icons.vibration_rounded,
                title: context.l10n.settingsNotificationVibration,
                value: settings?.notificationVibration ?? true,
                onChanged: (bool value) =>
                    controller.setNotificationVibration(value),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsReminderCategories),
          SettingsCard(
            children: [
              _reminderTile(
                context,
                ref,
                icon: Icons.fitness_center_rounded,
                title: context.l10n.settingsReminderWorkout,
                value: settings?.workoutReminderEnabled ?? true,
                onChanged: controller.setWorkoutReminder,
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              _reminderTile(
                context,
                ref,
                icon: Icons.restaurant_rounded,
                title: context.l10n.settingsReminderMeal,
                value: settings?.mealReminderEnabled ?? true,
                onChanged: controller.setMealReminder,
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              _reminderTile(
                context,
                ref,
                icon: Icons.water_drop_rounded,
                title: context.l10n.settingsReminderWater,
                value: settings?.waterReminderEnabled ?? true,
                onChanged: controller.setWaterReminder,
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              _reminderTile(
                context,
                ref,
                icon: Icons.monitor_weight_rounded,
                title: context.l10n.settingsReminderWeight,
                value: settings?.weightReminderEnabled ?? true,
                onChanged: controller.setWeightReminder,
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              _reminderTile(
                context,
                ref,
                icon: Icons.bedtime_rounded,
                title: context.l10n.settingsReminderSleep,
                value: settings?.sleepReminderEnabled ?? true,
                onChanged: controller.setSleepReminder,
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              _reminderTile(
                context,
                ref,
                icon: Icons.emoji_events_rounded,
                title: context.l10n.settingsReminderChallenge,
                value: settings?.challengeReminderEnabled ?? true,
                onChanged: controller.setChallengeReminder,
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              _reminderTile(
                context,
                ref,
                icon: Icons.workspace_premium_rounded,
                title: context.l10n.settingsReminderAchievement,
                value: settings?.achievementReminderEnabled ?? true,
                onChanged: controller.setAchievementReminder,
              ),
            ],
          ),
          AppSpacing.sm.heightSpace,
          Text(
            context.l10n.settingsReminderCategoriesSubtitle,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderTile(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required bool value,
    required Future<void> Function(bool) onChanged,
  }) {
    return SettingsSwitchTile(
      icon: icon,
      title: title,
      value: value,
      onChanged: (bool v) => onChanged(v),
    );
  }
}
