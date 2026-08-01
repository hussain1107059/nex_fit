import 'dart:io';
import 'dart:typed_data';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/network_info.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/backup_history.dart';
import '../../../domain/entities/backup_metadata.dart';
import '../../../domain/entities/backup_preview.dart';
import '../../../domain/entities/common_enums.dart';
import '../../../domain/entities/remote_backup_file.dart';
import '../../../domain/repositories/app_settings_repository.dart';
import '../../../domain/repositories/backup_history_repository.dart';
import '../../../domain/repositories/backup_repository.dart';
import '../../datasources/local/app_database.dart';
import '../storage/settings_storage_service.dart';
import 'backup_encryption_service.dart';
import 'backup_packaging_service.dart';

/// Outcome of a scheduled (automatic) backup attempt.
enum AutoBackupResult {
  disabled,
  notDue,
  noInternet,
  notSignedIn,
  notOnWifi,
  notCharging,
  done,
  failed,
}

/// Orchestrates full-database Google Drive backups: snapshot, compress,
/// encrypt, upload, retention, preview and restore.
class BackupService {
  BackupService({
    required this.repository,
    required this.historyRepository,
    required this.settingsRepository,
    required this.database,
    required this.storageService,
    required this.encryption,
    required this.packaging,
    required this.networkInfo,
    Logger? logger,
  }) : _logger = logger ?? Logger('BackupService');

  final BackupRepository repository;
  final BackupHistoryRepository historyRepository;
  final AppSettingsRepository settingsRepository;
  final AppDatabase database;
  final SettingsStorageService storageService;
  final BackupEncryptionService encryption;
  final BackupPackagingService packaging;
  final NetworkInfo networkInfo;
  final Logger _logger;

  /// Whether the current user has a usable Drive session.
  Future<bool> isDriveConnected() => repository.isBackupAvailable();

  Future<List<RemoteBackupFile>> listBackups() => repository.listBackups();

  /// Creates a full encrypted backup of the local database and uploads it to
  /// the private Drive AppData folder.
  Future<BackupHistory> createBackup({
    required String userId,
    BackupType type = BackupType.manual,
    void Function(double progress)? onProgress,
  }) async {
    final DateTime started = DateTime.now();

    try {
      if (!await networkInfo.isConnected) {
        throw const BackupException('backupNoInternet', code: 'no_internet');
      }
      onProgress?.call(0.1);

      final Uint8List? rawBytes = await storageService.createSnapshotBytes();
      if (rawBytes == null) {
        throw const BackupException('backupSnapshotFailed', code: 'snapshot');
      }
      onProgress?.call(0.4);

      final String deviceName = await _deviceName();
      final BackupMetadata metadata = BackupMetadata(
        createdAt: started,
        appVersion: AppConstants.appVersion,
        databaseVersion: AppConstants.databaseVersion,
        deviceName: deviceName,
      );

      final Uint8List fileBytes = await packaging.package(
        dbBytes: rawBytes,
        metadata: metadata,
      );
      onProgress?.call(0.6);

      if (!await repository.isBackupAvailable()) {
        throw const BackupException(
          'backupDriveDisconnected',
          code: 'drive_disconnected',
        );
      }

      final String fileName = _fileNameFor(started);
      final RemoteBackupFile remote = await repository.uploadBytes(
        bytes: fileBytes,
        fileName: fileName,
      );
      onProgress?.call(0.9);

      final BackupHistory history = BackupHistory(
        userId: userId,
        backupType: type,
        backupSizeBytes: fileBytes.length,
        fileName: remote.name,
        fileId: remote.id,
        status: BackupStatus.success,
        durationMs: DateTime.now().difference(started).inMilliseconds,
        appVersion: AppConstants.appVersion,
        databaseVersion: AppConstants.databaseVersion,
        deviceName: deviceName,
        checksum: _sha256Hex(rawBytes),
        encrypted: true,
        createdAt: started,
      );
      await historyRepository.insert(history);

      await _updateSettingsAfterBackup(userId, started);
      await _enforceRetention(userId);
      await _pruneLocalHistory(userId);

      onProgress?.call(1.0);
      return history;
    } catch (error, stackTrace) {
      _logger.warning('Backup failed: $error\n$stackTrace');
      try {
        await historyRepository.insert(
          BackupHistory(
            userId: userId,
            backupType: type,
            status: BackupStatus.failed,
            errorMessage: _messageFor(error),
            durationMs: DateTime.now().difference(started).inMilliseconds,
            createdAt: started,
          ),
        );
      } catch (_) {
        // Recording the failure must never mask the original error.
      }
      rethrow;
    }
  }

  /// Downloads a backup and reads its plaintext metadata (no decryption).
  Future<BackupPreview> previewBackup(RemoteBackupFile file) async {
    final Uint8List bytes = await repository.downloadBytes(file.id);
    final BackupMetadata metadata = packaging.readMetadata(bytes);
    return BackupPreview(file: file, metadata: metadata);
  }

  /// Restores the local database from a remote backup. The existing database
  /// is replaced; pending migrations are applied when the backup is from an
  /// older app version.
  Future<void> restoreBackup({
    required RemoteBackupFile file,
    void Function(double progress)? onProgress,
  }) async {
    final Uint8List fileBytes = await repository.downloadBytes(file.id);
    onProgress?.call(0.3);

    final BackupMetadata metadata = packaging.readMetadata(fileBytes);
    if (metadata.databaseVersion > AppConstants.databaseVersion) {
      throw const BackupException(
        'backupFromNewerVersion',
        code: 'newer_version',
      );
    }

    final Uint8List key = await encryption.getOrCreateKey();
    final Uint8List rawBytes = await packaging.unpack(
      fileBytes: fileBytes,
      key: key,
    );
    onProgress?.call(0.7);

    await _replaceDatabase(rawBytes);
    onProgress?.call(1.0);
    _logger.info('Database restored from ${file.name}');
  }

  Future<void> deleteBackup(String fileId) async {
    await repository.deleteBackup(fileId);
  }

  /// Removes every remote backup and clears the local Drive session.
  Future<void> signOutFromDrive() async {
    await repository.signOutFromDrive();
  }

  /// Runs an automatic backup when it is due and the conditions hold.
  Future<AutoBackupResult> runAutoBackupIfDue({
    required String userId,
  }) async {
    final AppSettings? settings = await settingsRepository.getByUserId(userId);
    if (settings == null || !settings.backupEnabled) {
      return AutoBackupResult.disabled;
    }
    final Duration? interval = settings.backupSchedule.interval;
    if (interval == null) return AutoBackupResult.notDue;

    final DateTime? last = settings.lastBackupAt;
    if (last != null &&
        DateTime.now().difference(last).inMilliseconds < interval.inMilliseconds) {
      return AutoBackupResult.notDue;
    }

    if (!await networkInfo.isConnected) return AutoBackupResult.noInternet;
    if (settings.backupOnWifiOnly &&
        await networkInfo.currentConnectivity != ConnectivityResult.wifi) {
      return AutoBackupResult.notOnWifi;
    }
    if (settings.backupWhileCharging && !await _isCharging()) {
      return AutoBackupResult.notCharging;
    }
    if (!await repository.isBackupAvailable()) {
      return AutoBackupResult.notSignedIn;
    }

    try {
      await createBackup(userId: userId, type: BackupType.auto);
      return AutoBackupResult.done;
    } catch (error, stackTrace) {
      _logger.warning('Scheduled backup failed: $error\n$stackTrace');
      return AutoBackupResult.failed;
    }
  }

  Future<void> _replaceDatabase(Uint8List rawBytes) async {
    if (kIsWeb) {
      throw const BackupException('backupNotSupportedOnWeb', code: 'web');
    }

    final String dbPath = await database.databaseFileRawPath;
    await database.close();

    final File dbFile = File(dbPath);
    final Directory parent = dbFile.parent;
    if (!await parent.exists()) await parent.create(recursive: true);

    for (final String suffix in const <String>['-wal', '-shm']) {
      final File sidecar = File('$dbPath$suffix');
      if (await sidecar.exists()) await sidecar.delete();
    }

    final File temp = File('$dbPath.tmp');
    await temp.writeAsBytes(rawBytes, flush: true);
    if (await dbFile.exists()) await dbFile.delete();
    await temp.rename(dbPath);

    // Eagerly reopen the replaced database so pending migrations (when the
    // backup is from an older app version) run right away and no provider can
    // open a stale handle to the deleted file in the meantime.
    await database.database;
  }

  Future<void> _updateSettingsAfterBackup(String userId, DateTime at) async {
    final AppSettings? settings = await settingsRepository.getByUserId(userId);
    if (settings == null) return;
    await settingsRepository.upsert(
      settings.copyWith(lastBackupAt: at, updatedAt: DateTime.now()),
    );
  }

  Future<void> _enforceRetention(String userId) async {
    final AppSettings? settings = await settingsRepository.getByUserId(userId);
    final int retention = settings?.backupRetentionCount ??
        AppConstants.backupDefaultRetention;
    final List<RemoteBackupFile> backups = await repository.listBackups();
    if (backups.length <= retention) return;
    for (final RemoteBackupFile file in backups.skip(retention)) {
      try {
        await repository.deleteBackup(file.id);
      } catch (error) {
        _logger.warning('Retention delete failed: $error');
      }
    }
  }

  Future<void> _pruneLocalHistory(String userId) async {
    const int maxHistory = 30;
    final List<BackupHistory> history =
        await historyRepository.getByUserId(userId);
    if (history.length <= maxHistory) return;
    for (final BackupHistory entry in history.skip(maxHistory)) {
      if (entry.id == null) continue;
      try {
        await historyRepository.delete(entry.id!);
      } catch (_) {}
    }
  }

  String _fileNameFor(DateTime at) {
    final String stamp =
        at.toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first;
    return '${AppConstants.backupFileNamePrefix}_$stamp.nxfbak';
  }

  Future<String> _deviceName() async {
    try {
      if (kIsWeb) return 'web';
      final DeviceInfoPlugin info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo android = await info.androidInfo;
        return android.model.isNotEmpty ? android.model : 'android';
      }
      if (Platform.isIOS) {
        final IosDeviceInfo ios = await info.iosInfo;
        return ios.utsname.machine.isNotEmpty ? ios.utsname.machine : 'ios';
      }
    } catch (_) {}
    return 'device';
  }

  Future<bool> _isCharging() async {
    try {
      if (kIsWeb) return true;
      final BatteryState state = await Battery().batteryState;
      return state == BatteryState.charging || state == BatteryState.full;
    } catch (_) {
      // When the battery plugin is unavailable, fall back to allowing the
      // automatic backup rather than silently dropping it.
      return true;
    }
  }

  String _sha256Hex(Uint8List bytes) => sha256.convert(bytes).toString();

  String _messageFor(Object error) {
    if (error is AppException) return error.message;
    return 'backupFailed';
  }
}
