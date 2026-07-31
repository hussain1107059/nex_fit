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
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }
}
