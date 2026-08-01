import 'dart:typed_data';

import 'package:_discoveryapis_commons/_discoveryapis_commons.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../../core/errors/app_exception.dart';
import '../auth/google_sign_in_service.dart';

/// Metadata for a single backup file stored in the Drive AppData folder.
class BackupFileInfo {
  const BackupFileInfo({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;
}

/// An open session holding both the [drive.DriveApi] and its [http.Client].
class _DriveSession {
  _DriveSession(this.api, this.client);

  final drive.DriveApi api;
  final http.Client client;
}

/// Uploads and restores app backups through the private Google Drive AppData
/// folder (`spaces: 'appData'`, `parents: ['appDataFolder']`). Files stored
/// here are invisible to the user's normal Drive and cannot be listed by other
/// apps.
class GoogleDriveBackupService {
  GoogleDriveBackupService({
    required this.signInService,
    Logger? logger,
  }) : _logger = logger ?? Logger('GoogleDriveBackupService');

  static const String filePrefix = 'nexfit_backup';
  static const int listPageSize = 100;

  final GoogleSignInService signInService;
  final Logger _logger;

  /// Whether the current user has a usable Google Drive session.
  Future<bool> isAvailable() async {
    final http.Client? client = await signInService.driveAuthorizedClient();
    if (client == null) return false;
    client.close();
    return true;
  }

  Future<_DriveSession> _openSession() async {
    final http.Client? client = await signInService.driveAuthorizedClient();
    if (client == null) {
      throw const BackupException(
        'backupDriveDisconnected',
        code: 'drive_disconnected',
      );
    }
    return _DriveSession(drive.DriveApi(client), client);
  }

  /// Uploads [bytes] into the AppData folder and returns the created file.
  Future<BackupFileInfo> uploadBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final _DriveSession session = await _openSession();
    try {
      final drive.File uploaded = await session.api.files.create(
        drive.File(
          name: fileName,
          parents: const ['appDataFolder'],
          mimeType: 'application/octet-stream',
        ),
        uploadMedia: drive.Media(
          Stream.value(bytes),
          bytes.length,
        ),
      );
      _logger.info('Backup uploaded: ${uploaded.id}');
      return BackupFileInfo(
        id: uploaded.id!,
        name: uploaded.name ?? fileName,
        createdAt: uploaded.createdTime?.toLocal() ?? DateTime.now(),
        sizeBytes: bytes.length,
      );
    } on ApiRequestError catch (error) {
      throw BackupException(
        _mapDriveError(_statusOf(error)),
        code: 'drive_upload_failed',
      );
    } finally {
      session.client.close();
    }
  }

  /// Lists backups stored in the AppData folder, newest first.
  Future<List<BackupFileInfo>> listBackups() async {
    final _DriveSession session = await _openSession();
    try {
      final drive.FileList result = await session.api.files.list(
        q: "name contains '$filePrefix' and trashed = false",
        spaces: 'appData',
        orderBy: 'createdTime desc',
        pageSize: listPageSize,
        $fields: 'files(id,name,createdTime,size)',
      );

      return (result.files ?? const <drive.File>[])
          .where((drive.File file) => file.id != null)
          .map(
            (drive.File file) => BackupFileInfo(
              id: file.id!,
              name: file.name ?? '',
              createdAt: file.createdTime?.toLocal() ?? DateTime.now(),
              sizeBytes: int.tryParse(file.size ?? '0') ?? 0,
            ),
          )
          .toList();
    } on ApiRequestError catch (error) {
      throw BackupException(
        _mapDriveError(_statusOf(error)),
        code: 'drive_list_failed',
      );
    } finally {
      session.client.close();
    }
  }

  /// Downloads a single backup file by id.
  Future<Uint8List> downloadBytes(String fileId) async {
    final _DriveSession session = await _openSession();
    try {
      final http.Response response = await session.client.get(
        Uri.parse(
          'https://www.googleapis.com/drive/v3/files/$fileId?alt=media',
        ),
      );
      if (response.statusCode != 200) {
        throw BackupException(
          _mapDriveError(response.statusCode),
          code: 'drive_download_failed',
        );
      }
      return response.bodyBytes;
    } on ApiRequestError catch (error) {
      throw BackupException(
        _mapDriveError(_statusOf(error)),
        code: 'drive_download_failed',
      );
    } finally {
      session.client.close();
    }
  }

  Future<void> deleteBackup(String fileId) async {
    final _DriveSession session = await _openSession();
    try {
      await session.api.files.delete(fileId);
    } on ApiRequestError catch (error) {
      throw BackupException(
        _mapDriveError(_statusOf(error)),
        code: 'drive_delete_failed',
      );
    } finally {
      session.client.close();
    }
  }

  /// Deletes every backup file owned by the app.
  Future<void> deleteAllBackups() async {
    final _DriveSession session = await _openSession();
    try {
      final List<BackupFileInfo> backups = await listBackups();
      for (final BackupFileInfo backup in backups) {
        await session.api.files.delete(backup.id);
      }
    } on ApiRequestError catch (error) {
      throw BackupException(
        _mapDriveError(_statusOf(error)),
        code: 'drive_delete_failed',
      );
    } finally {
      session.client.close();
    }
  }

  int? _statusOf(ApiRequestError error) {
    return error is DetailedApiRequestError ? error.status : null;
  }

  String _mapDriveError(int? status) {
    return switch (status) {
      null => 'errorNetwork',
      401 || 403 => 'backupDriveDisconnected',
      404 => 'backupNotFound',
      >= 500 => 'errorServer',
      _ => 'backupFailed',
    };
  }
}
