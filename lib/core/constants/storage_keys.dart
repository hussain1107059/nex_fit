/// Shared preference keys and secure storage keys used across the app.
class StorageKeys {
  StorageKeys._();

  static const String themeMode = 'theme_mode';
  static const String locale = 'locale';
  static const String onboarded = 'onboarded';
  static const String rememberMe = 'remember_me';
  static const String lastBackupAt = 'last_backup_at';

  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String googleAccessToken = 'google_access_token';
  static const String googleRefreshToken = 'google_refresh_token';
  static const String driveBackupEnabled = 'drive_backup_enabled';

  /// JSON-encoded list of locally created accounts used when Firebase is not
  /// configured (offline-first mode).
  static const String offlineUsers = 'offline_users';

  static const String notificationSound = 'notification_sound';
  static const String vibration = 'vibration';
  static const String silentMode = 'silent_mode';
  static const String reminderTimeFormat = 'reminder_time_format';
}
