import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import 'widgets/settings_widgets.dart';

/// Contact and help links.
class SupportSettingsScreen extends StatelessWidget {
  const SupportSettingsScreen({super.key});

  static const String _supportEmail =
      'support@nexfit.app';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsSupport)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          SettingsSectionTitle(context.l10n.settingsHelpCenter),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.support_agent_rounded,
                title: context.l10n.settingsContactSupport,
                subtitle: _supportEmail,
                onTap: () => _launch(
                  context,
                  'mailto:$_supportEmail?subject=${Uri.encodeComponent(context.l10n.settingsContactSubject)}',
                ),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.report_problem_rounded,
                title: context.l10n.settingsReportProblem,
                onTap: () => _launch(
                  context,
                  'mailto:$_supportEmail?subject=${Uri.encodeComponent(context.l10n.settingsReportSubject)}',
                ),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsLegal),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.policy_rounded,
                title: context.l10n.settingsPrivacyPolicy,
                onTap: () => _launch(
                  context,
                  'https://nexfit.app/privacy',
                ),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.gavel_rounded,
                title: context.l10n.settingsTerms,
                onTap: () => _launch(context, 'https://nexfit.app/terms'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _launch(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    try {
      final bool ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        AppSnackbar.error(context, context.l10n.settingsLinkFailed);
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.error(context, context.l10n.settingsLinkFailed);
      }
    }
  }
}
