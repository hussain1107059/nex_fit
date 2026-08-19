import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../dashboard/widgets/system_health_card.dart';

/// System health overview (sync, security, database and backup) moved out of
/// the home dashboard into Settings.
class SystemHealthSettingsScreen extends StatelessWidget {
  const SystemHealthSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dashboardSystemHealth)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: const [
          SystemHealthCard(),
        ],
      ),
    );
  }
}
