import 'package:equatable/equatable.dart';

/// Aggregate health of the local system, shown on the dashboard's System
/// Health card. Combines sync, security, database and backup signals.
class SystemHealth extends Equatable {
  const SystemHealth({
    this.dbHealthy = true,
    this.pendingSync = 0,
    this.failedSync = 0,
    this.lastSyncAt,
    this.encryptionEnabled = false,
    this.appLockEnabled = false,
    this.sessionValid = false,
    this.backupConnected = false,
    this.lastBackupAt,
    this.databaseSizeBytes = 0,
    this.lastCheckedAt,
  });

  final bool dbHealthy;
  final int pendingSync;
  final int failedSync;
  final DateTime? lastSyncAt;
  final bool encryptionEnabled;
  final bool appLockEnabled;
  final bool sessionValid;
  final bool backupConnected;
  final DateTime? lastBackupAt;
  final int databaseSizeBytes;
  final DateTime? lastCheckedAt;

  bool get allHealthy =>
      dbHealthy &&
      failedSync == 0 &&
      encryptionEnabled &&
      sessionValid;

  SystemHealth copyWith({
    bool? dbHealthy,
    int? pendingSync,
    int? failedSync,
    DateTime? lastSyncAt,
    bool? encryptionEnabled,
    bool? appLockEnabled,
    bool? sessionValid,
    bool? backupConnected,
    DateTime? lastBackupAt,
    int? databaseSizeBytes,
    DateTime? lastCheckedAt,
  }) {
    return SystemHealth(
      dbHealthy: dbHealthy ?? this.dbHealthy,
      pendingSync: pendingSync ?? this.pendingSync,
      failedSync: failedSync ?? this.failedSync,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      encryptionEnabled: encryptionEnabled ?? this.encryptionEnabled,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      sessionValid: sessionValid ?? this.sessionValid,
      backupConnected: backupConnected ?? this.backupConnected,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      databaseSizeBytes: databaseSizeBytes ?? this.databaseSizeBytes,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }

  @override
  List<Object?> get props => [
        dbHealthy,
        pendingSync,
        failedSync,
        lastSyncAt,
        encryptionEnabled,
        appLockEnabled,
        sessionValid,
        backupConnected,
        lastBackupAt,
        databaseSizeBytes,
        lastCheckedAt,
      ];
}
