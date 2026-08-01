import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart' show Database;

import '../../../domain/entities/remote_backup_file.dart';
import '../../../domain/entities/security_enums.dart';
import '../../datasources/local/app_database.dart';
import '../backup/backup_service.dart';
import 'app_error_logger.dart';

/// Result of an automatic recovery attempt.
class RecoveryResult {
  const RecoveryResult({required this.recovered, required this.healthy});

  /// True when the database was healthy or was successfully restored.
  final bool recovered;

  /// True when the database currently passes its integrity check.
  final bool healthy;
}

/// Database health monitoring and automatic recovery.
///
/// Runs `PRAGMA integrity_check` and, when corruption is detected, attempts to
/// restore the newest encrypted Drive backup over the damaged file. The
/// outcome is always surfaced through the error logger so the health card can
/// reflect it.
class RecoveryManager {
  RecoveryManager({
    required this.database,
    required this.backupService,
    required this.errorLogger,
    Logger? logger,
  }) : _logger = logger ?? Logger('RecoveryManager');

  final AppDatabase database;
  final BackupService backupService;
  final AppErrorLogger errorLogger;
  final Logger _logger;

  /// Whether the local database passes SQLite's integrity check.
  Future<DatabaseHealthStatus> checkHealth() async {
    if (kIsWeb) return DatabaseHealthStatus.healthy;
    try {
      final Database db = await database.database;
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'PRAGMA integrity_check',
      );
      final String result = rows.isEmpty
          ? 'ok'
          : (rows.first.values.first?.toString() ?? 'ok');
      final bool ok = result.trim().toLowerCase() == 'ok';
      if (!ok) {
        await errorLogger.log(
          category: ErrorCategory.database,
          message: 'integrity_check_failed: $result',
          context: 'recovery_manager',
        );
      }
      return ok ? DatabaseHealthStatus.healthy : DatabaseHealthStatus.corrupt;
    } catch (error, stackTrace) {
      _logger.warning('Integrity check failed: $error\n$stackTrace');
      return DatabaseHealthStatus.corrupt;
    }
  }

  /// Checks the database and restores the latest Drive backup when corrupted.
  ///
  /// Returns the recovery outcome. When corruption is found but no backup is
  /// available, the failure is logged and [RecoveryResult.recovered] stays
  /// false.
  Future<RecoveryResult> checkAndRecover({String? userId}) async {
    final DatabaseHealthStatus status = await checkHealth();
    if (status == DatabaseHealthStatus.healthy) {
      return const RecoveryResult(recovered: true, healthy: true);
    }

    _logger.severe('Database corruption detected; attempting recovery');
    final bool restored = await _restoreFromLatestBackup(userId: userId);
    if (!restored) {
      await errorLogger.log(
        category: ErrorCategory.database,
        message: 'recovery_failed_no_backup',
        context: 'recovery_manager',
      );
    }
    return RecoveryResult(
      recovered: restored,
      healthy: restored ? await checkHealth() == DatabaseHealthStatus.healthy : false,
    );
  }

  Future<bool> _restoreFromLatestBackup({String? userId}) async {
    try {
      final List<RemoteBackupFile> backups = await backupService.listBackups();
      if (backups.isEmpty) return false;
      await backupService.restoreBackup(file: backups.first);
      return true;
    } catch (error, stackTrace) {
      _logger.warning('Automatic recovery failed: $error\n$stackTrace');
      await errorLogger.log(
        category: ErrorCategory.backup,
        message: error.toString(),
        stackTrace: stackTrace.toString(),
        context: 'recovery_restore',
      );
      return false;
    }
  }
}
