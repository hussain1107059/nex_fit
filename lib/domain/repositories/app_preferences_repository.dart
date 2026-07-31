import 'package:flutter/material.dart';

/// Contract for reading and writing lightweight user preferences.
/// Implemented by [AppPreferencesRepositoryImpl] in the data layer.
abstract interface class AppPreferencesRepository {
  ThemeMode getThemeMode();

  Future<void> setThemeMode(ThemeMode mode);

  String? getLocale();

  Future<void> setLocale(String locale);

  bool isOnboarded();

  Future<void> setOnboarded(bool value);

  bool getRememberMe();

  Future<void> setRememberMe(bool value);

  DateTime? getLastBackupTime();

  Future<void> setLastBackupTime(DateTime time);
}
