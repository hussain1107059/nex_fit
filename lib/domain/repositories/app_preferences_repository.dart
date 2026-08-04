import '../entities/common_enums.dart';

/// Contract for reading and writing lightweight user preferences.
/// Implemented by [AppPreferencesRepositoryImpl] in the data layer.
abstract interface class AppPreferencesRepository {
  String? getLocale();

  Future<void> setLocale(String locale);

  bool isOnboarded();

  Future<void> setOnboarded(bool value);

  bool getRememberMe();

  Future<void> setRememberMe(bool value);

  DateTime? getLastBackupTime();

  Future<void> setLastBackupTime(DateTime time);

  bool getNotificationSound();

  Future<void> setNotificationSound(bool value);

  bool getVibration();

  Future<void> setVibration(bool value);

  bool getSilentMode();

  Future<void> setSilentMode(bool value);

  ReminderTimeFormat getReminderTimeFormat();

  Future<void> setReminderTimeFormat(ReminderTimeFormat format);
}
