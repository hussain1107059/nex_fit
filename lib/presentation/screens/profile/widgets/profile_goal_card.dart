import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/user_profile.dart';
import '../profile_labels.dart';
import 'profile_section_card.dart';

/// Shows the user's selected fitness goal and daily activity level.
class ProfileGoalCard extends StatelessWidget {
  const ProfileGoalCard({super.key, required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String dash = '—';
    final String goal = profile?.fitnessGoal == null
        ? dash
        : ProfileLabels.goal(l10n, profile!.fitnessGoal!);
    final String activity = profile?.activityLevel == null
        ? dash
        : ProfileLabels.activity(l10n, profile!.activityLevel!);

    return ProfileSectionCard(
      title: l10n.profileFitnessGoal,
      icon: Icons.track_changes_rounded,
      child: Column(
        children: [
          _GoalRow(
            icon: Icons.flag_rounded,
            label: l10n.profileFitnessGoal,
            value: goal,
          ),
          const SizedBox(height: AppSpacing.sm),
          _GoalRow(
            icon: Icons.directions_run_rounded,
            label: l10n.profileActivityLevel,
            value: activity,
          ),
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: AppRadius.mdRadius,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: AppRadius.smRadius,
            ),
            child: Icon(icon, size: 19, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: context.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
