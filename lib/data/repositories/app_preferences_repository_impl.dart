import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/storage_keys.dart';
import '../../domain/entities/common_enums.dart';
import '../../domain/repositories/app_preferences_repository.dart';

/// SharedPreferences backed implementation of [AppPreferencesRepository].
class AppPreferencesRepositoryImpl implements AppPreferencesRepository {
  AppPreferencesRepositoryImpl({this.preferences});

  SharedPreferences? preferences;

  Future<SharedPreferences> _getPreferences() async {
    return preferences ??= await SharedPreferences.getInstance();
  }

  @override
  ThemeMode getThemeMode() {
    final String? stored = preferences?.getString(StorageKeys.themeMode);
    if (stored == null) return ThemeMode.system;
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }

  @override
  Future<void> setThemeMode(ThemeMode mode) async {
    final SharedPreferences prefs = await _getPreferences();
    await prefs.setString(StorageKeys.themeMode, mode.name);
  }

  @override
  String? getLocale() {
    return preferences?.getString(StorageKeys.locale);
  }

  @override
  Future<void> setLocale(String locale) async {
    final SharedPreferences prefs = await _getPreferences();
    await prefs.setString(StorageKeys.locale, locale);
  }

  @override
  bool isOnboarded() {
    return preferences?.getBool(StorageKeys.onboarded) ?? false;
  }

  @override
  Future<void> setOnboarded(bool value) async {
    final SharedPreferences prefs = await _getPreferences();
    await prefs.setBool(StorageKeys.onboarded, value);
  }

  @override
  bool getRememberMe() {
    return preferences?.getBool(StorageKeys.rememberMe) ?? true;
  }

  @override
  Future<void> setRememberMe(bool value) async {
    final SharedPreferences prefs = await _getPreferences();
    await prefs.setBool(StorageKeys.rememberMe, value);
  }

  @override
  DateTime? getLastBackupTime() {
    final int? millis = preferences?.getInt(StorageKeys.lastBackupAt);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  Future<void> setLastBackupTime(DateTime time) async {
    final SharedPreferences prefs = await _getPreferences();
    await prefs.setInt(StorageKeys.lastBackupAt, time.millisecondsSinceEpoch);
  }

  @override
  bool getNotificationSound() {
    return preferences?.getBool(StorageKeys.notificationSound) ?? true;
  }

  @override
  Future<void> setNotificationSound(bool value) async {
    final SharedPreferences prefs = await _getPreferences();
    await prefs.setBool(StorageKeys.notificationSound, value);
  }

  @override
  bool getVibration() {
    return preferences?.getBool(StorageKeys.vibration) ?? true;
  }

  @override
  Future<void> setVibration(bool value) async {
    final SharedPreferences prefs = await _getPreferences();
    await prefs.setBool(StorageKeys.vibration, value);
  }

  @override
  bool getSilentMode() {
    return preferences?.getBool(StorageKeys.silentMode) ?? false;
  }

  @override
  Future<void> setSilentMode(bool value) async {
    final SharedPreferences prefs = await _getPreferences();
    await prefs.setBool(StorageKeys.silentMode, value);
  }

  @override
  ReminderTimeFormat getReminderTimeFormat() {
    final String? stored = preferences?.getString(StorageKeys.reminderTimeFormat);
    return ReminderTimeFormat.fromName(stored);
  }

  @override
  Future<void> setReminderTimeFormat(ReminderTimeFormat format) async {
    final SharedPreferences prefs = await _getPreferences();
    await prefs.setString(StorageKeys.reminderTimeFormat, format.name);
  }
}
