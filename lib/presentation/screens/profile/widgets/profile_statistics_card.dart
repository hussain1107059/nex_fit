import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/profile_data.dart';
import 'profile_section_card.dart';

/// Lifetime activity statistics aggregated from the local database.
class ProfileStatisticsCard extends StatelessWidget {
  const ProfileStatisticsCard({super.key, required this.stats});

  final ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String dash = '—';
    final String kcal = l10n.dashboardKcalUnit;
    final String kg = l10n.dashboardKgUnit;
    final String days = l10n.profileDays;

    final double waterLitres = stats.waterIntakeMl / 1000;
    final String waterValue =
        '${waterLitres.toStringAsFixed(1)} L'.toBanglaDigits();
    final double? weightLost = stats.weightLostKg;
    final String weightValue = weightLost == null || weightLost <= 0
        ? dash
        : '${weightLost.toStringAsFixed(1)} $kg'.toBanglaDigits();

    return ProfileSectionCard(
      title: l10n.profileStatistics,
      icon: Icons.insert_chart_rounded,
      child: GridView.count(
        crossAxisCount: context.isWide ? 3 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.2,
        children: [
          ProfileStatCell(
            icon: Icons.fitness_center_rounded,
            value: '${stats.totalWorkouts}'.toBanglaDigits(),
            label: l10n.profileTotalWorkouts,
            accent: true,
          ),
          ProfileStatCell(
            icon: Icons.local_fire_department_rounded,
            value: '${stats.currentStreak} $days'.toBanglaDigits(),
            label: l10n.profileCurrentStreak,
          ),
          ProfileStatCell(
            icon: Icons.emoji_events_rounded,
            value: '${stats.longestStreak} $days'.toBanglaDigits(),
            label: l10n.profileLongestStreak,
          ),
          ProfileStatCell(
            icon: Icons.whatshot_rounded,
            value: '${stats.caloriesBurned.round()} $kcal'.toBanglaDigits(),
            label: l10n.profileCaloriesBurned,
          ),
          ProfileStatCell(
            icon: Icons.water_drop_rounded,
            value: waterValue,
            label: l10n.profileWaterIntake,
          ),
          ProfileStatCell(
            icon: Icons.trending_down_rounded,
            value: weightValue,
            label: l10n.profileWeightLost,
          ),
        ],
      ),
    );
  }
}
