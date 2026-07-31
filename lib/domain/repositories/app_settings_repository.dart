import '../entities/app_settings.dart';

/// Contract for the user's per-account application settings.
abstract interface class AppSettingsRepository {
  Future<void> upsert(AppSettings settings);

  Future<AppSettings?> getByUserId(String userId);

  Future<void> delete(String userId);
}
