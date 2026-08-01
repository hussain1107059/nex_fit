import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_settings.dart';
import '../../providers/settings_providers.dart';
import 'widgets/settings_widgets.dart';

/// Daily nutrition targets: calories, macros, water.
class NutritionSettingsScreen extends ConsumerWidget {
  const NutritionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings? settings =
        ref.watch(settingsControllerProvider).valueOrNull;
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsNutrition)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          SettingsSectionTitle(context.l10n.settingsNutritionGoals),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.local_fire_department_rounded,
                title: context.l10n.settingsDailyCalories,
                value: _grams(context, settings?.dailyCalorieTarget),
                onTap: () => _editGoal<double>(
                  context: context,
                  title: context.l10n.settingsDailyCalories,
                  suffix: context.l10n.dashboardKcalUnit,
                  current: settings?.dailyCalorieTarget,
                  onSave: controller.setDailyCalories,
                ),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.egg_alt_rounded,
                title: context.l10n.settingsProtein,
                value: _grams(context, settings?.proteinGoal),
                onTap: () => _editGoal<double>(
                  context: context,
                  title: context.l10n.settingsProtein,
                  suffix: context.l10n.settingsGramUnit,
                  current: settings?.proteinGoal,
                  onSave: controller.setProteinGoal,
                ),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.grain_rounded,
                title: context.l10n.settingsCarbs,
                value: _grams(context, settings?.carbsGoal),
                onTap: () => _editGoal<double>(
                  context: context,
                  title: context.l10n.settingsCarbs,
                  suffix: context.l10n.settingsGramUnit,
                  current: settings?.carbsGoal,
                  onSave: controller.setCarbsGoal,
                ),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.bloodtype_rounded,
                title: context.l10n.settingsFat,
                value: _grams(context, settings?.fatGoal),
                onTap: () => _editGoal<double>(
                  context: context,
                  title: context.l10n.settingsFat,
                  suffix: context.l10n.settingsGramUnit,
                  current: settings?.fatGoal,
                  onSave: controller.setFatGoal,
                ),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.water_drop_rounded,
                title: context.l10n.settingsWater,
                value: settings?.dailyWaterTargetMl == null
                    ? '—'
                    : context.l10n.settingsMl(
                        settings!.dailyWaterTargetMl.toString(),
                      ),
                onTap: () => _editGoal<int>(
                  context: context,
                  title: context.l10n.settingsWater,
                  suffix: context.l10n.dashboardMlUnit,
                  current: settings?.dailyWaterTargetMl,
                  onSave: controller.setWaterGoal,
                ),
              ),
            ],
          ),
          AppSpacing.sm.heightSpace,
          Text(
            context.l10n.settingsNutritionSubtitle,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _grams(BuildContext context, double? value) =>
      value == null ? '—' : '${value.round().toString()} g';

  Future<void> _editGoal<T extends num>({
    required BuildContext context,
    required String title,
    required String suffix,
    required T? current,
    required Future<void> Function(T) onSave,
  }) async {
    final TextEditingController textController = TextEditingController(
      text: current?.toString() ?? '',
    );
    final String? input = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: textController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: InputDecoration(
              suffixText: suffix,
              hintText: context.l10n.settingsGoalHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(textController.text),
              child: Text(context.l10n.commonSave),
            ),
          ],
        );
      },
    );

    final String trimmed = input?.trim() ?? '';
    if (trimmed.isEmpty) return;

    final T? parsed = identical(T, double)
        ? double.tryParse(trimmed) as T?
        : int.tryParse(trimmed) as T?;
    if (parsed != null && parsed > 0) {
      await onSave(parsed);
    }
  }
}
