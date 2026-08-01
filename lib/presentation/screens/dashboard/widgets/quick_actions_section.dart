import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../domain/entities/dashboard_data.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../router/app_router.dart';
import 'dashboard_dialogs.dart';
import 'section_header.dart';

/// Six large quick action tiles wired to real dashboard dialogs.
class QuickActionsSection extends ConsumerWidget {
  const QuickActionsSection({
    super.key,
    required this.userId,
    required this.summary,
  });

  final String userId;
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = context.isDarkMode ? AppColors.dark : AppColors.light;
    final List<_QuickActionData> items = <_QuickActionData>[
      _QuickActionData(
        icon: Icons.fitness_center_rounded,
        label: context.l10n.dashboardStartWorkout,
        color: colors.primary,
      ),
      _QuickActionData(
        icon: Icons.water_drop_rounded,
        label: context.l10n.dashboardLogWater,
        color: colors.info,
      ),
      _QuickActionData(
        icon: Icons.restaurant_rounded,
        label: context.l10n.dashboardAddMeal,
        color: colors.warning,
      ),
      _QuickActionData(
        icon: Icons.monitor_weight_rounded,
        label: context.l10n.dashboardLogWeight,
        color: colors.tertiary,
      ),
      _QuickActionData(
        icon: Icons.calculate_rounded,
        label: context.l10n.dashboardBmiCalculator,
        color: colors.success,
      ),
      _QuickActionData(
        icon: Icons.bedtime_rounded,
        label: context.l10n.dashboardSleepTracker,
        color: colors.secondary,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: context.l10n.dashboardQuickActions),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = context.isWide ? 6 : 3;
            final double spacing = AppSpacing.sm;
            final double cell = (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (int i = 0; i < items.length; i++)
                  SizedBox(
                    width: cell,
                    child: _QuickActionTile(
                      data: items[i],
                      onTap: () => _handleAction(context, ref, i),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, int index) {
    switch (index) {
      case 0:
        AppSnackbar.info(context, context.l10n.dashboardComingSoon);
        break;
      case 1:
        context.push(AppRoutes.water);
        break;
      case 2:
        AppSnackbar.info(context, context.l10n.dashboardComingSoon);
        break;
      case 3:
        ref.read(shellTabIndexProvider.notifier).state = 2;
        break;
      case 4:
        DashboardDialogs.showBmiCalculator(
          context,
          ref,
          userId,
          latestWeight: summary.weightKg,
        );
        break;
      case 5:
        AppSnackbar.info(context, context.l10n.dashboardComingSoon);
        break;
    }
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.data, required this.onTap});

  final _QuickActionData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colorScheme.surface,
      borderRadius: AppRadius.mdRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdRadius,
        child: Container(
          height: 92,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdRadius,
            border: Border.all(color: context.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(data.icon, size: 20, color: data.color),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                data.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}
