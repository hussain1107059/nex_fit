import '../../../l10n/app_localizations.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/common_enums.dart';

/// Localized labels for profile enums shared by the profile and edit screens.
class ProfileLabels {
  ProfileLabels._();

  static String gender(AppLocalizations l10n, Gender gender) {
    return switch (gender) {
      Gender.male => l10n.genderMale,
      Gender.female => l10n.genderFemale,
      Gender.other => l10n.genderOther,
    };
  }

  static String goal(AppLocalizations l10n, GoalType goal) {
    return switch (goal) {
      GoalType.weightLoss => l10n.goalWeightLoss,
      GoalType.weightGain => l10n.goalWeightGain,
      GoalType.maintainWeight => l10n.goalMaintainWeight,
      GoalType.muscleBuilding => l10n.goalMuscleGain,
      GoalType.generalFitness => l10n.goalGeneralFitness,
      GoalType.other => l10n.profileNotSet,
    };
  }

  static String activity(AppLocalizations l10n, ActivityLevel level) {
    return switch (level) {
      ActivityLevel.sedentary => l10n.activitySedentary,
      ActivityLevel.light => l10n.activityLight,
      ActivityLevel.moderate => l10n.activityModerate,
      ActivityLevel.active => l10n.activityVeryActive,
      ActivityLevel.veryActive => l10n.activityVeryActive,
      ActivityLevel.athlete => l10n.activityAthlete,
    };
  }

  static String provider(AppLocalizations l10n, AuthProvider provider) {
    return switch (provider) {
      AuthProvider.google => l10n.providerGoogle,
      AuthProvider.email => l10n.providerEmail,
      AuthProvider.none => l10n.profileNotSet,
    };
  }
}
