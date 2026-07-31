import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import 'dashboard_dialogs.dart';

/// Empty state prompting the user to log their first weight entry.
class EmptyWeightCard extends ConsumerWidget {
  const EmptyWeightCard({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.colorScheme.tertiaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.monitor_weight_rounded,
                color: context.colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.dashboardNoWeightYet,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    context.l10n.dashboardNoWeightYetSubtitle,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filledTonal(
              onPressed: () {
                DashboardDialogs.showLogWeight(context, ref, userId);
              },
              icon: const Icon(Icons.add_rounded),
              tooltip: context.l10n.dashboardLogWeight,
            ),
          ],
        ),
      ),
    );
  }
}
