import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// A single animated circular goal ring with a value in the centre.
class GoalRing extends StatelessWidget {
  const GoalRing({
    super.key,
    required this.progress,
    required this.valueText,
    required this.label,
    required this.icon,
    required this.color,
    this.targetText,
    this.goalSet = true,
  });

  /// Fraction between 0 and 1, or 0 when no target is configured.
  final double progress;
  final String valueText;
  final String label;
  final IconData icon;
  final Color color;
  final String? targetText;
  final bool goalSet;

  @override
  Widget build(BuildContext context) {
    final AppColors appColors =
        AppColors.light;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: context.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double value, Widget? child) {
              return SizedBox(
                width: 62,
                height: 62,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: value,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      color: color,
                      backgroundColor: context.colorScheme.surfaceContainerHighest,
                    ),
                    Center(
                      child: Text(
                        valueText,
                        style: context.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          if (targetText != null && goalSet)
            Text(
              targetText!,
              textAlign: TextAlign.center,
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            )
          else if (!goalSet)
            Text(
              context.l10n.dashboardGoalNotSet,
              textAlign: TextAlign.center,
              style: context.textTheme.labelSmall?.copyWith(
                color: appColors.warning,
              ),
            ),
        ],
      ),
    );
  }
}
