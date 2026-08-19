import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/release_logger.dart';
import '../../data/services/security/encryption_service.dart';
import '../../data/services/security/key_manager.dart';
import '../../data/services/security/pin_hasher.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/common_enums.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';
import 'locale_provider.dart';
import 'profile_providers.dart';
import 'reminder_providers.dart';

/// Applies the field-encryption facade configuration so the data models start
/// encrypting/decrypting sensitive values.
Future<void> configureFieldEncryption(
  KeyManager keyManager, {
  required bool enabled,
}) {
  return FieldEncryption.configure(keyManager: keyManager, enabled: enabled);
}

/// Hashes and verifies the app-lock PIN. Versioned PBKDF2-HMAC-SHA256 with a
/// random salt; legacy static-salt hashes are still accepted on verify.
final PinHasher _pinHasher = PinHasher();

/// Loads and mutates the signed-in user's persisted [AppSettings].
///
/// The controller is per-user (watches [currentUserProvider]) and every setter
/// updates the in-memory state immediately, persists to SQFlite and refreshes
/// any dependent feature (notifications, theming, security).
class SettingsController extends AsyncNotifier<AppSettings?> {
  AppSettingsRepository get _repository =>
      ref.read(appSettingsRepositoryProvider);

  @override
  Future<AppSettings?> build() {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) return Future.value();
    return _repository.getByUserId(user.id);
  }

  Future<void> refresh() async {
    state = AsyncValue<AppSettings?>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(build);
  }

  AppSettings _defaultsFor(String userId) {
    return AppSettings(userId: userId, updatedAt: DateTime.now());
  }

  /// Applies [transform] to the current settings (or defaults), persists and
  /// publishes the new value instantly.
  Future<AppSettings?> _update(
    AppSettings Function(AppSettings) transform,
  ) async {
    return _apply(
      transform,
      trackSync: true,
    );
  }

  /// Like [_update] but writes device-local telemetry (last sync / last active
  /// time) WITHOUT bumping row_version or enqueuing a sync event. Tracking
  /// these would re-stamp the timestamp after every sync run, queueing a fresh
  /// UPDATE event each time so the outbox can never drain.
  Future<AppSettings?> _updateSilent(
    AppSettings Function(AppSettings) transform,
  ) async {
    return _apply(
      transform,
      trackSync: false,
    );
  }

  Future<AppSettings?> _apply(
    AppSettings Function(AppSettings) transform, {
    required bool trackSync,
  }) async {
    final AppUser? user = ref.read(currentUserProvider);
    if (user == null || !user.isSignedIn) return state.valueOrNull;

    final AppSettings? current = state.valueOrNull;
    final AppSettings updated = transform(
      current ?? _defaultsFor(user.id),
    ).copyWith(updatedAt: DateTime.now());

    await _repository.upsert(updated, trackSync: trackSync);
    state = AsyncData<AppSettings?>(updated);
    return updated;
  }

  // ---------------------------------------------------------------------
  // General
  // ---------------------------------------------------------------------

  Future<void> setUnits(Units units) =>
      _update((settings) => settings.copyWith(units: units));

  Future<void> setWeekStart(WeekStart start) =>
      _update((settings) => settings.copyWith(weekStart: start));

  // ---------------------------------------------------------------------
  // Language
  // ---------------------------------------------------------------------

  /// Persists the language to SQFlite and switches the active app locale
  /// immediately.
  Future<void> setLocale(String languageCode) async {
    await _update((settings) => settings.copyWith(locale: languageCode));
    await ref.read(localeProvider.notifier).setLocale(Locale(languageCode));
  }

  // ---------------------------------------------------------------------
  // Appearance
  // ---------------------------------------------------------------------

  Future<void> setDynamicColor(bool enabled) =>
      _update((settings) => settings.copyWith(dynamicColor: enabled));

  Future<void> setFontScale(FontScale scale) =>
      _update((settings) => settings.copyWith(fontScale: scale));

  // ---------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _update((settings) => settings.copyWith(notificationsEnabled: enabled));
    final service = ref.read(localNotificationServiceProvider);
    if (!enabled) {
      await service.cancelAll();
    } else {
      await rescheduleRemindersInContainer(ref.container);
    }
  }

  Future<void> setNotificationSound(bool enabled) async {
    await _update((settings) => settings.copyWith(notificationSound: enabled));
    await rescheduleRemindersInContainer(ref.container);
  }

  Future<void> setNotificationVibration(bool enabled) async {
    await _update(
      (settings) => settings.copyWith(notificationVibration: enabled),
    );
    await rescheduleRemindersInContainer(ref.container);
  }

  Future<void> setWorkoutReminder(bool enabled) =>
      _update((settings) => settings.copyWith(workoutReminderEnabled: enabled));

  Future<void> setMealReminder(bool enabled) =>
      _update((settings) => settings.copyWith(mealReminderEnabled: enabled));

  Future<void> setWaterReminder(bool enabled) =>
      _update((settings) => settings.copyWith(waterReminderEnabled: enabled));

  Future<void> setWeightReminder(bool enabled) =>
      _update((settings) => settings.copyWith(weightReminderEnabled: enabled));

  Future<void> setSleepReminder(bool enabled) =>
      _update((settings) => settings.copyWith(sleepReminderEnabled: enabled));

  Future<void> setChallengeReminder(bool enabled) =>
      _update((settings) => settings.copyWith(challengeReminderEnabled: enabled));

  Future<void> setAchievementReminder(bool enabled) => _update(
    (settings) => settings.copyWith(achievementReminderEnabled: enabled),
  );

  // ---------------------------------------------------------------------
  // Workout
  // ---------------------------------------------------------------------

  Future<void> setDefaultRestTime(int seconds) =>
      _update((settings) => settings.copyWith(defaultRestTimeSeconds: seconds));

  Future<void> setAutoStartTimer(bool enabled) =>
      _update((settings) => settings.copyWith(autoStartTimer: enabled));

  Future<void> setCountdownVoice(bool enabled) =>
      _update((settings) => settings.copyWith(countdownVoice: enabled));

  Future<void> setExerciseAnimation(bool enabled) =>
      _update((settings) => settings.copyWith(exerciseAnimation: enabled));

  Future<void> setAutoNextExercise(bool enabled) =>
      _update((settings) => settings.copyWith(autoNextExercise: enabled));

  // ---------------------------------------------------------------------
  // Nutrition goals
  // ---------------------------------------------------------------------

  Future<void> setDailyCalories(double? value) =>
      _update((settings) => settings.copyWith(dailyCalorieTarget: value));

  Future<void> setProteinGoal(double? value) =>
      _update((settings) => settings.copyWith(proteinGoal: value));

  Future<void> setCarbsGoal(double? value) =>
      _update((settings) => settings.copyWith(carbsGoal: value));

  Future<void> setFatGoal(double? value) =>
      _update((settings) => settings.copyWith(fatGoal: value));

  Future<void> setWaterGoal(int? value) =>
      _update((settings) => settings.copyWith(dailyWaterTargetMl: value));

  // ---------------------------------------------------------------------
  // Backup / sync
  // ---------------------------------------------------------------------

  Future<void> setBackupEnabled(bool enabled) =>
      _update((settings) => settings.copyWith(backupEnabled: enabled));

  Future<void> setBackupSchedule(BackupSchedule schedule) =>
      _update((settings) => settings.copyWith(backupSchedule: schedule));

  Future<void> setBackupRetention(int count) => _update(
        (settings) => settings.copyWith(
          backupRetentionCount: count
              .clamp(1, AppConstants.backupMaxRetention)
              .toInt(),
        ),
      );

  Future<void> setBackupOnWifiOnly(bool enabled) =>
      _update((settings) => settings.copyWith(backupOnWifiOnly: enabled));

  Future<void> setBackupWhileCharging(bool enabled) =>
      _update((settings) => settings.copyWith(backupWhileCharging: enabled));

  Future<void> setLastBackupAt(DateTime at) =>
      _update((settings) => settings.copyWith(lastBackupAt: at));

  Future<void> setDataSyncEnabled(bool enabled) =>
      _update((settings) => settings.copyWith(dataSyncEnabled: enabled));

  // ---------------------------------------------------------------------
  // Developer
  // ---------------------------------------------------------------------

  Future<void> setLogsEnabled(bool enabled) async {
    await _update((settings) => settings.copyWith(logsEnabled: enabled));
    Logger.root.level = enabled ? Level.ALL : Level.INFO;
    devLog('[SETTINGS] Logs enabled: $enabled');
  }

  /// Restores every setting to its default value for the signed-in user.
  Future<void> resetSettings() async {
    final AppUser? user = ref.read(currentUserProvider);
    if (user == null || !user.isSignedIn) return;
    await _repository.upsert(_defaultsFor(user.id));
    await refresh();
  }

  // ---------------------------------------------------------------------
  // Security
  // ---------------------------------------------------------------------

  bool hasPin() => (state.valueOrNull?.pinHash ?? '').isNotEmpty;

  Future<bool> verifyPin(String pin) async {
    final String? hash = state.valueOrNull?.pinHash;
    if (hash == null || hash.isEmpty) return false;
    final bool ok = _pinHasher.verifyPin(pin, hash);
    // Upgrade a legacy (pre-PBKDF2) hash to the versioned format in place so
    // the stronger scheme applies from the next unlock onward.
    if (ok && !PinHasher.isVersioned(hash)) {
      await setPin(pin);
    }
    return ok;
  }

  Future<void> setPin(String pin) async {
    await _update((settings) => settings.copyWith(pinHash: _pinHasher.hashPin(pin)));
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    await _update(
      (settings) => settings.copyWith(
        appLockEnabled: enabled,
        biometricEnabled: enabled ? settings.biometricEnabled : false,
      ),
    );
  }

  Future<void> setBiometricEnabled(bool enabled) =>
      _update((settings) => settings.copyWith(biometricEnabled: enabled));

  Future<void> setAutoLock(AutoLockDelay delay) =>
      _update((settings) => settings.copyWith(autoLock: delay));

  Future<void> setSessionTimeout(int minutes) =>
      _update((settings) => settings.copyWith(sessionTimeoutMinutes: minutes));

  Future<void> setHideRecentApps(bool enabled) async {
    await _update((settings) => settings.copyWith(hideRecentApps: enabled));
    await ref
        .read(appSecurityServiceProvider)
        .applyHideRecentApps(enabled);
  }

  /// Blocks screenshots and screen recording via FLAG_SECURE.
  Future<void> setScreenshotLock(bool enabled) async {
    await _update((settings) => settings.copyWith(screenshotLock: enabled));
    await ref.read(appSecurityServiceProvider).applyScreenshotLock(enabled);
  }

  /// Toggles field-level encryption. When enabled, the encryption key is
  /// (re)loaded into the [FieldEncryption] facade; when disabled the facade is
  /// switched off so writes stay plaintext.
  Future<void> setEncryptionEnabled(bool enabled) async {
    await _update((settings) => settings.copyWith(encryptionEnabled: enabled));
    await configureFieldEncryption(
      ref.read(keyManagerProvider),
      enabled: enabled,
    );
  }

  /// Records the last successful sync queue processing run (device-local
  /// telemetry: never enqueues a sync event).
  Future<void> setLastSyncAt(DateTime at) =>
      _updateSilent((settings) => settings.copyWith(lastSyncAt: at));

  /// Records the last active moment, used by the auto-lock gate (device-local
  /// telemetry: never enqueues a sync event).
  Future<void> markActive() =>
      _updateSilent((settings) => settings.copyWith(lastActiveAt: DateTime.now()));

  /// Wipes every locally stored row for the signed-in user (cascading delete),
  /// then re-seeds the shared catalogs so the app starts fresh but offline.
  Future<void> deleteLocalData() async {
    final AppUser? user = ref.read(currentUserProvider);
    if (user == null || !user.isSignedIn) return;

    await ref.read(userLocalDataSourceProvider).deleteProfile(user.id);
    ref.invalidate(profileControllerProvider);
    ref.invalidate(dashboardRepositoryProvider);
    ref.invalidate(profileSettingsProvider);

    final AppSettings? fresh = await _repository.getByUserId(user.id);
    if (fresh == null) {
      await _repository.upsert(_defaultsFor(user.id));
    }
    await refresh();
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings?>(
      SettingsController.new,
    );

/// Owns whether the app-lock screen is currently covering the app.
class AppLockController extends Notifier<bool> {
  @override
  bool build() => false;

  void lock() => state = true;

  /// Unlocks the app and stamps the last-active time so auto-lock restarts.
  Future<void> unlock() async {
    state = false;
    await ref.read(settingsControllerProvider.notifier).markActive();
  }
}

final appLockProvider = NotifierProvider<AppLockController, bool>(
  AppLockController.new,
);

/// Whether biometric unlocking is available on this device.
final biometricAvailableProvider = FutureProvider<bool>((ref) {
  return ref.watch(appSecurityServiceProvider).isBiometricSupported();
});

/// Whether app lock is enabled for the signed-in user.
final appLockEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsControllerProvider).valueOrNull?.appLockEnabled ??
      false;
});

/// Size of the local SQLite database in bytes.
final databaseSizeProvider = FutureProvider<int>((ref) {
  return ref.watch(settingsStorageServiceProvider).databaseSizeBytes();
});

/// Size of the cached profile photos in bytes.
final imageCacheSizeProvider = FutureProvider<int>((ref) {
  return ref.watch(settingsStorageServiceProvider).imageCacheSizeBytes();
});
