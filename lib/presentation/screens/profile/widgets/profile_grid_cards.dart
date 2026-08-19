import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/health_calculator.dart';
import '../../../../domain/entities/user_profile.dart';
import '../profile_labels.dart';
import 'profile_section_card.dart';

/// Responsive grid of the user's physical details.
class ProfilePhysicalCard extends StatelessWidget {
  const ProfilePhysicalCard({super.key, required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String kg = l10n.dashboardKgUnit;
    final String cm = 'cm';
    final String dash = '—';

    final int? age = HealthCalculator.age(profile?.birthDate);
    final String height = profile?.heightCm == null
        ? dash
        : '${profile!.heightCm!.toStringAsFixed(0)} $cm'.toBanglaDigits();
    final String weight = profile?.weightKg == null
        ? dash
        : '${profile!.weightKg!.toStringAsFixed(1)} $kg'.toBanglaDigits();
    final String targetWeight = profile?.targetWeightKg == null
        ? dash
        : '${profile!.targetWeightKg!.toStringAsFixed(1)} $kg'
              .toBanglaDigits();
    final String gender = profile?.gender == null
        ? dash
        : ProfileLabels.gender(l10n, profile!.gender!);
    final String ageValue = age == null ? dash : '$age'.toBanglaDigits();

    return ProfileSectionCard(
      title: l10n.profilePhysicalInfo,
      icon: Icons.accessibility_new_rounded,
      child: GridView.count(
        crossAxisCount: context.isWide ? 3 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 112,
        children: [
          ProfileStatCell(
            icon: Icons.cake_rounded,
            value: '$ageValue ${l10n.profileYears}',
            label: l10n.profileAge,
          ),
          ProfileStatCell(
            icon: Icons.wc_rounded,
            value: gender,
            label: l10n.profileGender,
          ),
          ProfileStatCell(
            icon: Icons.height_rounded,
            value: height,
            label: l10n.profileHeight,
          ),
          ProfileStatCell(
            icon: Icons.monitor_weight_rounded,
            value: weight,
            label: l10n.profileCurrentWeight,
            accent: true,
          ),
          ProfileStatCell(
            icon: Icons.flag_rounded,
            value: targetWeight,
            label: l10n.profileTargetWeight,
          ),
        ],
      ),
    );
  }
}

/// Responsive grid of the daily calorie, water and step targets.
class ProfileTargetsCard extends StatelessWidget {
  const ProfileTargetsCard({super.key, required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String dash = '—';
    final String kcal = l10n.dashboardKcalUnit;
    final String ml = l10n.dashboardMlUnit;

    final String calories = profile?.targetCalories == null
        ? dash
        : '${profile!.targetCalories!.round()} $kcal'.toBanglaDigits();
    final String water = profile?.targetWaterMl == null
        ? dash
        : '${profile!.targetWaterMl} $ml'.toBanglaDigits();
    final String steps = profile?.targetSteps == null
        ? dash
        : '${profile!.targetSteps}'.toBanglaDigits();

    return ProfileSectionCard(
      title: l10n.profileDailyTargets,
      icon: Icons.flag_rounded,
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 112,
        children: [
          ProfileStatCell(
            icon: Icons.local_fire_department_rounded,
            value: calories,
            label: l10n.profileDailyCaloriesTarget,
            accent: true,
          ),
          ProfileStatCell(
            icon: Icons.water_drop_rounded,
            value: water,
            label: l10n.profileDailyWaterTarget,
          ),
          ProfileStatCell(
            icon: Icons.directions_walk_rounded,
            value: steps,
            label: l10n.profileDailyStepTarget,
          ),
        ],
      ),
    );
  }
}
