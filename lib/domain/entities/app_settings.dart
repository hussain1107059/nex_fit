import 'package:equatable/equatable.dart';

import 'common_enums.dart';

/// Per-user application preferences, targets and security settings.
///
/// Stored as a single row inside the `app_settings` table so every value
/// persists offline and is restored after an app restart.
class AppSettings extends Equatable {
  const AppSettings({
    this.id,
    required this.userId,
    this.theme,
    this.locale,
    this.units = Units.metric,
    this.dailyCalorieTarget,
    this.dailyWaterTargetMl,
    this.dailyStepTarget,
    this.notificationsEnabled = true,
    this.reminderEnabled = true,
    this.dataSyncEnabled = true,
    this.backupEnabled = true,
    this.lastBackupAt,
    this.backupSchedule = BackupSchedule.manual,
    this.backupRetentionCount = 5,
    this.backupOnWifiOnly = false,
    this.backupWhileCharging = false,
    this.dynamicColor = false,
    this.fontScale = FontScale.medium,
    this.weekStart = WeekStart.sunday,
    this.notificationSound = true,
    this.notificationVibration = true,
    this.workoutReminderEnabled = true,
    this.mealReminderEnabled = true,
    this.waterReminderEnabled = true,
    this.weightReminderEnabled = true,
    this.sleepReminderEnabled = true,
    this.challengeReminderEnabled = true,
    this.achievementReminderEnabled = true,
    this.defaultRestTimeSeconds = 60,
    this.autoStartTimer = false,
    this.countdownVoice = true,
    this.exerciseAnimation = true,
    this.autoNextExercise = true,
    this.proteinGoal,
    this.carbsGoal,
    this.fatGoal,
    this.appLockEnabled = false,
    this.pinHash,
    this.biometricEnabled = false,
    this.autoLock = AutoLockDelay.minutes1,
    this.sessionTimeoutMinutes = 30,
    this.hideRecentApps = false,
    this.logsEnabled = false,
    this.lastActiveAt,
    this.encryptionEnabled = true,
    this.screenshotLock = false,
    this.lastSyncAt,
    required this.updatedAt,
  });

  final int? id;
  final String userId;
  final String? theme;
  final String? locale;
  final Units units;
  final double? dailyCalorieTarget;
  final int? dailyWaterTargetMl;
  final int? dailyStepTarget;
  final bool notificationsEnabled;
  final bool reminderEnabled;
  final bool dataSyncEnabled;
  final bool backupEnabled;
  final DateTime? lastBackupAt;

  // Backup & restore
  final BackupSchedule backupSchedule;
  final int backupRetentionCount;
  final bool backupOnWifiOnly;
  final bool backupWhileCharging;

  // Appearance
  final bool dynamicColor;
  final FontScale fontScale;

  // General
  final WeekStart weekStart;

  // Notification module preferences
  final bool notificationSound;
  final bool notificationVibration;
  final bool workoutReminderEnabled;
  final bool mealReminderEnabled;
  final bool waterReminderEnabled;
  final bool weightReminderEnabled;
  final bool sleepReminderEnabled;
  final bool challengeReminderEnabled;
  final bool achievementReminderEnabled;

  // Workout module preferences
  final int defaultRestTimeSeconds;
  final bool autoStartTimer;
  final bool countdownVoice;
  final bool exerciseAnimation;
  final bool autoNextExercise;

  // Nutrition goals (calories/water reuse the existing daily targets)
  final double? proteinGoal;
  final double? carbsGoal;
  final double? fatGoal;

  // Security
  final bool appLockEnabled;
  final String? pinHash;
  final bool biometricEnabled;
  final AutoLockDelay autoLock;
  final int sessionTimeoutMinutes;
  final bool hideRecentApps;

  // Developer
  final bool logsEnabled;

  /// Timestamp of the last time the app was actively unlocked; used by the
  /// auto-lock gate to decide whether a PIN prompt must be shown again.
  final DateTime? lastActiveAt;

  // Security & encryption
  final bool encryptionEnabled;
  final bool screenshotLock;

  /// Timestamp of the last successful sync queue processing run.
  final DateTime? lastSyncAt;

  final DateTime updatedAt;

  AppSettings copyWith({
    int? id,
    String? userId,
    String? theme,
    String? locale,
    Units? units,
    double? dailyCalorieTarget,
    int? dailyWaterTargetMl,
    int? dailyStepTarget,
    bool? notificationsEnabled,
    bool? reminderEnabled,
    bool? dataSyncEnabled,
    bool? backupEnabled,
    DateTime? lastBackupAt,
    BackupSchedule? backupSchedule,
    int? backupRetentionCount,
    bool? backupOnWifiOnly,
    bool? backupWhileCharging,
    bool? dynamicColor,
    FontScale? fontScale,
    WeekStart? weekStart,
    bool? notificationSound,
    bool? notificationVibration,
    bool? workoutReminderEnabled,
    bool? mealReminderEnabled,
    bool? waterReminderEnabled,
    bool? weightReminderEnabled,
    bool? sleepReminderEnabled,
    bool? challengeReminderEnabled,
    bool? achievementReminderEnabled,
    int? defaultRestTimeSeconds,
    bool? autoStartTimer,
    bool? countdownVoice,
    bool? exerciseAnimation,
    bool? autoNextExercise,
    double? proteinGoal,
    double? carbsGoal,
    double? fatGoal,
    bool? appLockEnabled,
    String? pinHash,
    bool? biometricEnabled,
    AutoLockDelay? autoLock,
    int? sessionTimeoutMinutes,
    bool? hideRecentApps,
    bool? logsEnabled,
    DateTime? lastActiveAt,
    bool? encryptionEnabled,
    bool? screenshotLock,
    DateTime? lastSyncAt,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      theme: theme ?? this.theme,
      locale: locale ?? this.locale,
      units: units ?? this.units,
      dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
      dailyWaterTargetMl: dailyWaterTargetMl ?? this.dailyWaterTargetMl,
      dailyStepTarget: dailyStepTarget ?? this.dailyStepTarget,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      dataSyncEnabled: dataSyncEnabled ?? this.dataSyncEnabled,
      backupEnabled: backupEnabled ?? this.backupEnabled,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      backupSchedule: backupSchedule ?? this.backupSchedule,
      backupRetentionCount:
          backupRetentionCount ?? this.backupRetentionCount,
      backupOnWifiOnly: backupOnWifiOnly ?? this.backupOnWifiOnly,
      backupWhileCharging: backupWhileCharging ?? this.backupWhileCharging,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      fontScale: fontScale ?? this.fontScale,
      weekStart: weekStart ?? this.weekStart,
      notificationSound: notificationSound ?? this.notificationSound,
      notificationVibration:
          notificationVibration ?? this.notificationVibration,
      workoutReminderEnabled:
          workoutReminderEnabled ?? this.workoutReminderEnabled,
      mealReminderEnabled: mealReminderEnabled ?? this.mealReminderEnabled,
      waterReminderEnabled: waterReminderEnabled ?? this.waterReminderEnabled,
      weightReminderEnabled: weightReminderEnabled ?? this.weightReminderEnabled,
      sleepReminderEnabled: sleepReminderEnabled ?? this.sleepReminderEnabled,
      challengeReminderEnabled:
          challengeReminderEnabled ?? this.challengeReminderEnabled,
      achievementReminderEnabled:
          achievementReminderEnabled ?? this.achievementReminderEnabled,
      defaultRestTimeSeconds: defaultRestTimeSeconds ?? this.defaultRestTimeSeconds,
      autoStartTimer: autoStartTimer ?? this.autoStartTimer,
      countdownVoice: countdownVoice ?? this.countdownVoice,
      exerciseAnimation: exerciseAnimation ?? this.exerciseAnimation,
      autoNextExercise: autoNextExercise ?? this.autoNextExercise,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      carbsGoal: carbsGoal ?? this.carbsGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      pinHash: pinHash ?? this.pinHash,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoLock: autoLock ?? this.autoLock,
      sessionTimeoutMinutes: sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      hideRecentApps: hideRecentApps ?? this.hideRecentApps,
      logsEnabled: logsEnabled ?? this.logsEnabled,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
      screenshotLock: screenshotLock ?? this.screenshotLock,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        theme,
        locale,
        units,
        dailyCalorieTarget,
        dailyWaterTargetMl,
        dailyStepTarget,
        notificationsEnabled,
        reminderEnabled,
        dataSyncEnabled,
        backupEnabled,
        lastBackupAt,
        backupSchedule,
        backupRetentionCount,
        backupOnWifiOnly,
        backupWhileCharging,
        dynamicColor,
        fontScale,
        weekStart,
        notificationSound,
        notificationVibration,
        workoutReminderEnabled,
        mealReminderEnabled,
        waterReminderEnabled,
        weightReminderEnabled,
        sleepReminderEnabled,
        challengeReminderEnabled,
        achievementReminderEnabled,
        defaultRestTimeSeconds,
        autoStartTimer,
        countdownVoice,
        exerciseAnimation,
        autoNextExercise,
        proteinGoal,
        carbsGoal,
        fatGoal,
        appLockEnabled,
        pinHash,
        biometricEnabled,
        autoLock,
        sessionTimeoutMinutes,
        hideRecentApps,
        logsEnabled,
        lastActiveAt,
        encryptionEnabled,
        screenshotLock,
        lastSyncAt,
        updatedAt,
      ];
}
