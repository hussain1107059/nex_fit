import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/sync/sync_engine.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/security_enums.dart';
import '../../domain/entities/system_health.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';
import 'backup_providers.dart';
import 'settings_providers.dart';
import 'sync_providers.dart';

/// Aggregates the signals shown on the dashboard's System Health card: sync
/// queue, security posture, database integrity and backup health.
final systemHealthProvider = FutureProvider<SystemHealth>((ref) async {
  final AppUser? user = ref.watch(currentUserProvider);
  final AppSettings? settings = ref.watch(settingsControllerProvider).valueOrNull;
  final SyncUiState sync = ref.watch(syncControllerProvider);
  final bool connected =
      ref.watch(driveConnectedProvider).valueOrNull ?? false;

  final SyncQueueSnapshot? snapshot = sync.snapshot;

  DatabaseHealthStatus dbHealth = DatabaseHealthStatus.healthy;
  int dbSize = 0;
  try {
    dbHealth = await ref.watch(recoveryManagerProvider).checkHealth();
  } catch (_) {
    dbHealth = DatabaseHealthStatus.corrupt;
  }
  try {
    dbSize = await ref.watch(settingsStorageServiceProvider).databaseSizeBytes();
  } catch (_) {}

  return SystemHealth(
    dbHealthy: dbHealth == DatabaseHealthStatus.healthy,
    pendingSync: snapshot?.pending ?? 0,
    failedSync: snapshot?.failed ?? 0,
    lastSyncAt: snapshot?.lastSyncedAt ?? settings?.lastSyncAt,
    encryptionEnabled: settings?.encryptionEnabled ?? true,
    appLockEnabled: settings?.appLockEnabled ?? false,
    sessionValid: user != null && user.isSignedIn,
    backupConnected: connected,
    lastBackupAt: settings?.lastBackupAt,
    databaseSizeBytes: dbSize,
    lastCheckedAt: DateTime.now(),
  );
});
