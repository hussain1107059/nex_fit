// Shared enums used across the fitness domain. Each enum is persisted by
// its [Enum.name] value inside the local SQLite database.

/// Fitness level of a workout or exercise.
enum Difficulty {
  beginner,
  intermediate,
  advanced;

  static Difficulty fromName(String? value) {
    return Difficulty.values.firstWhere(
      (difficulty) => difficulty.name == value,
      orElse: () => Difficulty.beginner,
    );
  }
}

/// Biological sex used for profile targets.
enum Gender {
  male,
  female,
  other;

  static Gender fromName(String? value) {
    return Gender.values.firstWhere(
      (gender) => gender.name == value,
      orElse: () => Gender.other,
    );
  }
}

/// Daily activity level used to estimate targets.
enum ActivityLevel {
  sedentary,
  light,
  moderate,
  active,
  veryActive,
  athlete;

  static ActivityLevel fromName(String? value) {
    return ActivityLevel.values.firstWhere(
      (level) => level.name == value,
      orElse: () => ActivityLevel.moderate,
    );
  }
}

/// The kind of fitness goal a user can set.
enum GoalType {
  weightLoss,
  weightGain,
  maintainWeight,
  muscleBuilding,
  generalFitness,
  other;

  static GoalType fromName(String? value) {
    return GoalType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => GoalType.other,
    );
  }
}

/// Lifecycle state of a fitness goal.
enum GoalStatus {
  active,
  completed,
  abandoned;

  static GoalStatus fromName(String? value) {
    return GoalStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => GoalStatus.active,
    );
  }
}

/// Type of a scheduled reminder.
enum ReminderType {
  workout,
  water,
  meal,
  weight,
  sleep,
  medicine,
  step,
  custom;

  static ReminderType fromName(String? value) {
    return ReminderType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ReminderType.custom,
    );
  }
}

/// How a reminder repeats.
enum ReminderScheduleType {
  oneTime,
  daily,
  weekly,
  monthly,
  customDays;

  static ReminderScheduleType fromName(String? value) {
    return ReminderScheduleType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ReminderScheduleType.daily,
    );
  }
}

/// Lifecycle state of a single reminder occurrence.
enum ReminderHistoryStatus {
  completed,
  missed,
  skipped;

  static ReminderHistoryStatus fromName(String? value) {
    return ReminderHistoryStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ReminderHistoryStatus.missed,
    );
  }
}

/// Display format used for reminder times in the UI.
enum ReminderTimeFormat {
  h12,
  h24;

  static ReminderTimeFormat fromName(String? value) {
    return ReminderTimeFormat.values.firstWhere(
      (format) => format.name == value,
      orElse: () => ReminderTimeFormat.h12,
    );
  }
}

/// What kind of habit a [Streak] tracks.
enum StreakType {
  workout,
  water,
  step,
  sleep,
  daily;

  static StreakType fromName(String? value) {
    return StreakType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => StreakType.daily,
    );
  }
}

/// Result state of a backup operation.
enum BackupStatus {
  inProgress,
  success,
  failed;

  static BackupStatus fromName(String? value) {
    return BackupStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => BackupStatus.inProgress,
    );
  }
}

/// Who triggered a backup.
enum BackupType {
  manual,
  auto;

  static BackupType fromName(String? value) {
    return BackupType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => BackupType.manual,
    );
  }
}

/// Measurement units for preferences.
enum Units {
  metric,
  imperial;

  static Units fromName(String? value) {
    return Units.values.firstWhere(
      (units) => units.name == value,
      orElse: () => Units.metric,
    );
  }
}
