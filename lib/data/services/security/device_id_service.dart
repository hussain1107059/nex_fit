import '../../../core/constants/app_constants.dart';
import '../../../core/security/uuid_generator.dart';
import '../storage/secure_storage_service.dart';

/// Stable, per-install device identity for the two-way sync outbox.
///
/// The id is a UUID v4 generated exactly once, persisted in secure storage and
/// reused across restarts and app upgrades. It contains no PII or credentials;
/// it identifies the installation so multi-device conflicts can be attributed.
///
/// This is the single source of truth for `device_id` on sync events. The
/// legacy 12-hex ids produced by earlier versions remain readable for backward
/// compatibility but new ids are always UUID v4.
class DeviceIdService {
  DeviceIdService({required this.storage});

  final SecureStorageService storage;
  Future<String?>? _cached;

  Future<String?> _load() {
    return _cached ??= storage.read(AppConstants.deviceIdStorageKey);
  }

  /// Returns the stable device id, creating and persisting it on first use.
  Future<String> getOrCreate() async {
    final String? existing = await _load();
    if (existing != null && existing.isNotEmpty) return existing;
    final String id = UuidGenerator.v4();
    await storage.write(AppConstants.deviceIdStorageKey, id);
    _cached = Future<String?>.value(id);
    return id;
  }

  /// Clears the persisted device id (used by the test seam / full reset).
  Future<void> delete() async {
    await storage.delete(AppConstants.deviceIdStorageKey);
    _cached = storage.read(AppConstants.deviceIdStorageKey);
  }
}
