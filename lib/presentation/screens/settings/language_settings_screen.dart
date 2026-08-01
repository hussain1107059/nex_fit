import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../providers/settings_providers.dart';
import 'widgets/settings_widgets.dart';

/// Language selection. The app is Bangla-first with English as the secondary
/// locale; the choice is persisted and applied immediately.
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String current =
        ref.watch(settingsControllerProvider).valueOrNull?.locale ??
        AppConstants.defaultLocale;
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsLanguage)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          SettingsSectionTitle(context.l10n.settingsLanguage),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.translate_rounded,
                title: context.l10n.editLanguageBangla,
                selected: current == 'bn',
                onTap: () => controller.setLocale('bn'),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.translate_rounded,
                title: context.l10n.editLanguageEnglish,
                selected: current == 'en',
                onTap: () => controller.setLocale('en'),
              ),
            ],
          ),
          AppSpacing.sm.heightSpace,
          Text(
            context.l10n.settingsLanguageSubtitle,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
