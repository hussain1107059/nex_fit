import '../entities/app_settings.dart';

/// Contract for the user's per-account application settings.
abstract interface class AppSettingsRepository {
  /// Persists [settings]. When [trackSync] is true (the default) the write
  /// bumps `row_version` and enqueues an UPDATE outbox event so the change
  /// reaches the server. Device-local telemetry (last sync / last active time)
  /// must pass `trackSync: false` so it never spawns a sync event — otherwise
  /// every sync run re-stamps the timestamp, queues another event, and the
  /// queue can never drain (push/pull echo loop).
  Future<void> upsert(AppSettings settings, {bool trackSync = true});

  Future<AppSettings?> getByUserId(String userId);

  Future<void> delete(String userId);
}
