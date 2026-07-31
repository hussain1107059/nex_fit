import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/health_calculator.dart';
import '../../../../domain/entities/user_profile.dart';
import 'profile_section_card.dart';

/// Displays the automatically computed BMI, its category, the healthy weight
/// range for the user's height and a personalised suggestion.
class ProfileBmiCard extends StatelessWidget {
  const ProfileBmiCard({super.key, required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final double? bmi = HealthCalculator.bmi(
      weightKg: profile?.weightKg,
      heightCm: profile?.heightCm,
    );
    final range = HealthCalculator.healthyRange(profile?.heightCm);
    final ColorScheme scheme = context.colorScheme;

    final Widget content;
    if (bmi == null) {
      content = _IncompleteHint(
        icon: Icons.calculate_rounded,
        text: context.l10n.profileIncomplete,
      );
    } else {
      final BmiCategory category = HealthCalculator.classify(bmi);
      final Color accent = _categoryColor(scheme, category);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _BmiValue(bmi: bmi, color: accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryPill(category: category, accent: accent),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _healthyRangeLabel(context, range),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: AppRadius.mdRadius,
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 18, color: accent),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    _suggestion(context, category),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ProfileSectionCard(
      title: context.l10n.profileBmi,
      icon: Icons.monitor_weight_rounded,
      child: content,
    );
  }

  String _healthyRangeLabel(
    BuildContext context,
    ({double minKg, double maxKg})? range,
  ) {
    final String l10nKg = context.l10n.dashboardKgUnit;
    if (range == null) return context.l10n.profileNotSet;
    final String min = range.minKg.toStringAsFixed(1).toBanglaDigits();
    final String max = range.maxKg.toStringAsFixed(1).toBanglaDigits();
    return '${context.l10n.profileHealthyRange}: $min – $max $l10nKg';
  }

  Color _categoryColor(ColorScheme scheme, BmiCategory category) {
    return switch (category) {
      BmiCategory.underweight => scheme.tertiary,
      BmiCategory.normal => scheme.primary,
      BmiCategory.overweight => const Color(0xFFF59E0B),
      BmiCategory.obese => scheme.error,
    };
  }

  String _suggestion(BuildContext context, BmiCategory category) {
    final l10n = context.l10n;
    return switch (category) {
      BmiCategory.underweight => l10n.bmiSuggestionUnderweight,
      BmiCategory.normal => l10n.bmiSuggestionNormal,
      BmiCategory.overweight => l10n.bmiSuggestionOverweight,
      BmiCategory.obese => l10n.bmiSuggestionObese,
    };
  }
}

class _BmiValue extends StatelessWidget {
  const _BmiValue({required this.bmi, required this.color});

  final double bmi;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            bmi.toStringAsFixed(1).toBanglaDigits(),
            style: context.textTheme.headlineMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            context.l10n.profileBmiValue,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category, required this.accent});

  final BmiCategory category;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final String label = switch (category) {
      BmiCategory.underweight => context.l10n.bmiUnderweight,
      BmiCategory.normal => context.l10n.bmiNormal,
      BmiCategory.overweight => context.l10n.bmiOverweight,
      BmiCategory.obese => context.l10n.bmiObese,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        '${context.l10n.profileBmiCategory}: $label',
        style: context.textTheme.labelMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IncompleteHint extends StatelessWidget {
  const _IncompleteHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
