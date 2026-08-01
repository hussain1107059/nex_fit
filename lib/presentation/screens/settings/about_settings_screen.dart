import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs/app_dialog.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../providers/auth_controller.dart';
import 'widgets/settings_widgets.dart';

/// App info and account-level destructive actions.
class AboutSettingsScreen extends ConsumerWidget {
  const AboutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = context.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsAbout)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: scheme.primaryContainer.withValues(alpha: 0.5),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SvgPicture.asset(AppAssets.logo, fit: BoxFit.contain),
            ),
          ),
          AppSpacing.md.heightSpace,
          Text(
            AppConstants.appName,
            textAlign: TextAlign.center,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          AppSpacing.xs.heightSpace,
          Text(
            '${context.l10n.settingsAboutVersion} 1.0.0',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.sm.heightSpace,
          Text(
            context.l10n.settingsAboutMessage,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.xl.heightSpace,
          SettingsSectionTitle(context.l10n.settingsAccount),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.delete_outline_rounded,
                title: context.l10n.settingsDeleteAccount,
                subtitle: context.l10n.settingsDeleteAccountSubtitle,
                destructive: true,
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: context.l10n.settingsDeleteAccount,
      message: context.l10n.settingsDeleteAccountConfirm,
      confirmLabel: context.l10n.settingsDeleteAccountAction,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(authControllerProvider.notifier).deleteAccount();
    if (result.isFailure && context.mounted) {
      AppSnackbar.error(context, context.l10n.settingsDeleteAccountFailed);
    }
  }
}
