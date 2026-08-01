import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../domain/entities/common_enums.dart';
import '../../providers/reminder_providers.dart';

/// Device-level reminder notification settings: sound, vibration, silent mode
/// and the reminder time format.
class ReminderSettingsScreen extends ConsumerWidget {
  const ReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReminderSettingsState settings = ref.watch(reminderSettingsProvider);
    final ReminderSettingsController controller =
        ref.read(reminderSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.remindersSettings),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            context.l10n.remindersSettingsSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    Icons.volume_up_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(context.l10n.remindersSound),
                  subtitle: Text(context.l10n.remindersSoundSubtitle),
                  value: settings.soundEnabled && !settings.silentMode,
                  onChanged: (bool value) => controller.setSoundEnabled(value),
                ),
                SwitchListTile(
                  secondary: Icon(
                    Icons.vibration_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(context.l10n.remindersVibration),
                  subtitle: Text(context.l10n.remindersVibrationSubtitle),
                  value: settings.vibrationEnabled && !settings.silentMode,
                  onChanged: (bool value) =>
                      controller.setVibrationEnabled(value),
                ),
                SwitchListTile(
                  secondary: Icon(
                    Icons.notifications_off_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(context.l10n.remindersSilent),
                  subtitle: Text(context.l10n.remindersSilentSubtitle),
                  value: settings.silentMode,
                  onChanged: (bool value) => controller.setSilentMode(value),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.remindersTimeFormat,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: RadioGroup<ReminderTimeFormat>(
              groupValue: settings.timeFormat,
              onChanged: (ReminderTimeFormat? value) {
                if (value != null) {
                  controller.setTimeFormat(value);
                  AppSnackbar.success(context, context.l10n.remindersSaved);
                }
              },
              child: Column(
                children: [
                  RadioListTile<ReminderTimeFormat>(
                    title: Text(context.l10n.remindersTimeFormat12h),
                    value: ReminderTimeFormat.h12,
                  ),
                  RadioListTile<ReminderTimeFormat>(
                    title: Text(context.l10n.remindersTimeFormat24h),
                    value: ReminderTimeFormat.h24,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
