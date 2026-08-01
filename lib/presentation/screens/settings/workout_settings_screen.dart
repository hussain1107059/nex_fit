import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_settings.dart';
import '../../providers/settings_providers.dart';
import 'widgets/settings_widgets.dart';

/// Defaults applied when running a workout: rest length, countdown and
/// player behaviour.
class WorkoutSettingsScreen extends ConsumerWidget {
  const WorkoutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings? settings =
        ref.watch(settingsControllerProvider).valueOrNull;
    final controller = ref.read(settingsControllerProvider.notifier);
    final int restSeconds = settings?.defaultRestTimeSeconds ?? 60;

    String restLabel(int seconds) =>
        context.l10n.settingsRestSeconds(seconds.toString());

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsWorkout)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          SettingsSectionTitle(context.l10n.settingsWorkoutTiming),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.timer_rounded,
                title: context.l10n.settingsDefaultRestTime,
                value: restLabel(restSeconds),
                onTap: () async {
                  final int? selected = await showSettingsChoices<int>(
                    context: context,
                    title: context.l10n.settingsDefaultRestTime,
                    icon: Icons.timer_rounded,
                    current: restSeconds,
                    choices: [30, 45, 60, 90, 120, 180]
                        .map(
                          (int seconds) => SettingsChoice<int>(
                            label: restLabel(seconds),
                            value: seconds,
                          ),
                        )
                        .toList(),
                  );
                  if (selected != null) {
                    await controller.setDefaultRestTime(selected);
                  }
                },
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsWorkoutBehaviour),
          SettingsCard(
            children: [
              SettingsSwitchTile(
                icon: Icons.play_circle_outline_rounded,
                title: context.l10n.settingsAutoStartTimer,
                value: settings?.autoStartTimer ?? false,
                onChanged: (bool value) =>
                    controller.setAutoStartTimer(value),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsSwitchTile(
                icon: Icons.record_voice_over_rounded,
                title: context.l10n.settingsCountdownVoice,
                value: settings?.countdownVoice ?? true,
                onChanged: (bool value) => controller.setCountdownVoice(value),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsSwitchTile(
                icon: Icons.animation_rounded,
                title: context.l10n.settingsExerciseAnimation,
                value: settings?.exerciseAnimation ?? true,
                onChanged: (bool value) =>
                    controller.setExerciseAnimation(value),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsSwitchTile(
                icon: Icons.skip_next_rounded,
                title: context.l10n.settingsAutoNextExercise,
                value: settings?.autoNextExercise ?? true,
                onChanged: (bool value) => controller.setAutoNextExercise(value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
