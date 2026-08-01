import '../../domain/entities/app_settings.dart';
import '../../domain/entities/common_enums.dart';
import 'model_codec.dart';

/// Maps [AppSettings] to and from rows in the `app_settings` table.
class AppSettingsModel {
  AppSettingsModel._();

  static const String table = 'app_settings';

  static Map<String, Object?> toMap(AppSettings settings) {
    return <String, Object?>{
      'id': settings.id,
      'user_id': settings.userId,
      'theme': settings.theme,
      'locale': settings.locale,
      'units': settings.units.name,
      'daily_calorie_target': settings.dailyCalorieTarget,
      'daily_water_target_ml': settings.dailyWaterTargetMl,
      'daily_step_target': settings.dailyStepTarget,
      'notifications_enabled':
          ModelCodec.boolToInt(settings.notificationsEnabled),
      'reminder_enabled': ModelCodec.boolToInt(settings.reminderEnabled),
      'data_sync_enabled': ModelCodec.boolToInt(settings.dataSyncEnabled),
      'backup_enabled': ModelCodec.boolToInt(settings.backupEnabled),
      'last_backup_at': ModelCodec.epochMs(settings.lastBackupAt),
      'backup_schedule': settings.backupSchedule.name,
      'backup_retention_count': settings.backupRetentionCount,
      'backup_on_wifi_only': ModelCodec.boolToInt(settings.backupOnWifiOnly),
      'backup_while_charging':
          ModelCodec.boolToInt(settings.backupWhileCharging),
      'theme_mode': settings.themeMode.name,
      'dynamic_color': ModelCodec.boolToInt(settings.dynamicColor),
      'font_scale': settings.fontScale.name,
      'week_start': settings.weekStart.name,
      'notification_sound': ModelCodec.boolToInt(settings.notificationSound),
      'notification_vibration': ModelCodec.boolToInt(
        settings.notificationVibration,
      ),
      'workout_reminder_enabled': ModelCodec.boolToInt(
        settings.workoutReminderEnabled,
      ),
      'meal_reminder_enabled': ModelCodec.boolToInt(
        settings.mealReminderEnabled,
      ),
      'water_reminder_enabled': ModelCodec.boolToInt(
        settings.waterReminderEnabled,
      ),
      'weight_reminder_enabled': ModelCodec.boolToInt(
        settings.weightReminderEnabled,
      ),
      'sleep_reminder_enabled': ModelCodec.boolToInt(
        settings.sleepReminderEnabled,
      ),
      'challenge_reminder_enabled': ModelCodec.boolToInt(
        settings.challengeReminderEnabled,
      ),
      'achievement_reminder_enabled': ModelCodec.boolToInt(
        settings.achievementReminderEnabled,
      ),
      'default_rest_time_seconds': settings.defaultRestTimeSeconds,
      'auto_start_timer': ModelCodec.boolToInt(settings.autoStartTimer),
      'countdown_voice': ModelCodec.boolToInt(settings.countdownVoice),
      'exercise_animation': ModelCodec.boolToInt(settings.exerciseAnimation),
      'auto_next_exercise': ModelCodec.boolToInt(settings.autoNextExercise),
      'protein_goal': settings.proteinGoal,
      'carbs_goal': settings.carbsGoal,
      'fat_goal': settings.fatGoal,
      'app_lock_enabled': ModelCodec.boolToInt(settings.appLockEnabled),
      'pin_hash': settings.pinHash,
      'biometric_enabled': ModelCodec.boolToInt(settings.biometricEnabled),
      'auto_lock': settings.autoLock.name,
      'session_timeout_minutes': settings.sessionTimeoutMinutes,
      'hide_recent_apps': ModelCodec.boolToInt(settings.hideRecentApps),
      'logs_enabled': ModelCodec.boolToInt(settings.logsEnabled),
      'last_active_at': ModelCodec.epochMs(settings.lastActiveAt),
      'screenshot_lock': ModelCodec.boolToInt(settings.screenshotLock),
      'encryption_enabled': ModelCodec.boolToInt(settings.encryptionEnabled),
      'last_sync_at': ModelCodec.epochMs(settings.lastSyncAt),
      'updated_at': ModelCodec.epochMs(settings.updatedAt),
    };
  }

  static AppSettings fromMap(Map<String, Object?> row) {
    return AppSettings(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      theme: row['theme'] as String?,
      locale: row['locale'] as String?,
      units: Units.fromName(row['units'] as String?),
      dailyCalorieTarget: ModelCodec.toDouble(row['daily_calorie_target']),
      dailyWaterTargetMl: row['daily_water_target_ml'] as int?,
      dailyStepTarget: row['daily_step_target'] as int?,
      notificationsEnabled: ModelCodec.intToBool(row['notifications_enabled']),
      reminderEnabled: ModelCodec.intToBool(row['reminder_enabled']),
      dataSyncEnabled: ModelCodec.intToBool(row['data_sync_enabled']),
      backupEnabled: ModelCodec.intToBool(row['backup_enabled']),
      lastBackupAt: ModelCodec.fromEpochMs(row['last_backup_at'] as int?),
      backupSchedule: BackupSchedule.fromName(row['backup_schedule'] as String?),
      backupRetentionCount: row['backup_retention_count'] as int? ?? 5,
      backupOnWifiOnly: ModelCodec.intToBool(row['backup_on_wifi_only']),
      backupWhileCharging: ModelCodec.intToBool(row['backup_while_charging']),
      themeMode: AppThemeMode.fromName(row['theme_mode'] as String?),
      dynamicColor: ModelCodec.intToBool(row['dynamic_color']),
      fontScale: FontScale.fromName(row['font_scale'] as String?),
      weekStart: WeekStart.fromName(row['week_start'] as String?),
      notificationSound: ModelCodec.intToBool(row['notification_sound']),
      notificationVibration: ModelCodec.intToBool(
        row['notification_vibration'],
      ),
      workoutReminderEnabled: ModelCodec.intToBool(
        row['workout_reminder_enabled'],
      ),
      mealReminderEnabled: ModelCodec.intToBool(row['meal_reminder_enabled']),
      waterReminderEnabled: ModelCodec.intToBool(
        row['water_reminder_enabled'],
      ),
      weightReminderEnabled: ModelCodec.intToBool(
        row['weight_reminder_enabled'],
      ),
      sleepReminderEnabled: ModelCodec.intToBool(row['sleep_reminder_enabled']),
      challengeReminderEnabled: ModelCodec.intToBool(
        row['challenge_reminder_enabled'],
      ),
      achievementReminderEnabled: ModelCodec.intToBool(
        row['achievement_reminder_enabled'],
      ),
      defaultRestTimeSeconds: row['default_rest_time_seconds'] as int? ?? 60,
      autoStartTimer: ModelCodec.intToBool(row['auto_start_timer']),
      countdownVoice: ModelCodec.intToBool(row['countdown_voice']),
      exerciseAnimation: ModelCodec.intToBool(row['exercise_animation']),
      autoNextExercise: ModelCodec.intToBool(row['auto_next_exercise']),
      proteinGoal: ModelCodec.toDouble(row['protein_goal']),
      carbsGoal: ModelCodec.toDouble(row['carbs_goal']),
      fatGoal: ModelCodec.toDouble(row['fat_goal']),
      appLockEnabled: ModelCodec.intToBool(row['app_lock_enabled']),
      pinHash: row['pin_hash'] as String?,
      biometricEnabled: ModelCodec.intToBool(row['biometric_enabled']),
      autoLock: AutoLockDelay.fromName(row['auto_lock'] as String?),
      sessionTimeoutMinutes: row['session_timeout_minutes'] as int? ?? 30,
      hideRecentApps: ModelCodec.intToBool(row['hide_recent_apps']),
      logsEnabled: ModelCodec.intToBool(row['logs_enabled']),
      lastActiveAt: ModelCodec.fromEpochMs(row['last_active_at'] as int?),
      screenshotLock: ModelCodec.intToBool(row['screenshot_lock']),
      encryptionEnabled: ModelCodec.intToBool(row['encryption_enabled']),
      lastSyncAt: ModelCodec.fromEpochMs(row['last_sync_at'] as int?),
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }
}
