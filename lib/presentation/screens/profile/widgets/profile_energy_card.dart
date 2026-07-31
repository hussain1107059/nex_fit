import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/health_calculator.dart';
import '../../../../domain/entities/user_profile.dart';
import 'profile_section_card.dart';

/// Shows the automatically computed BMR and the daily calorie requirement.
class ProfileEnergyCard extends StatelessWidget {
  const ProfileEnergyCard({super.key, required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final int? age = HealthCalculator.age(profile?.birthDate);
    final double? bmr = HealthCalculator.bmr(
      weightKg: profile?.weightKg,
      heightCm: profile?.heightCm,
      age: age,
      gender: profile?.gender,
    );
    final double? dailyCalories = HealthCalculator.dailyCalories(
      bmrValue: bmr,
      level: profile?.activityLevel,
    );
    final ColorScheme scheme = context.colorScheme;

    final Widget content;
    if (bmr == null) {
      content = Row(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.profileIncomplete,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    } else {
      final String bmrLabel = '${bmr.round()}'.toBanglaDigits();
      final String kcal = context.l10n.dashboardKcalUnit;
      content = Row(
        children: [
          Expanded(
            child: _EnergyBlock(
              icon: Icons.bolt_rounded,
              value: '$bmrLabel $kcal',
              label: context.l10n.profileBmr,
              accent: scheme.tertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _EnergyBlock(
              icon: Icons.local_fire_department_rounded,
              value: dailyCalories == null
                  ? '—'
                  : '${dailyCalories.round()} $kcal'.toBanglaDigits(),
              label: context.l10n.profileDailyCalories,
              accent: scheme.secondary,
            ),
          ),
        ],
      );
    }

    return ProfileSectionCard(
      title: context.l10n.profileDailyCaloriesTarget,
      icon: Icons.local_fire_department_rounded,
      child: content,
    );
  }
}

class _EnergyBlock extends StatelessWidget {
  const _EnergyBlock({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
