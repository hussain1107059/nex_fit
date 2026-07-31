import 'dart:convert';
import 'dart:typed_data';

import 'package:_discoveryapis_commons/_discoveryapis_commons.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../../core/errors/app_exception.dart';
import '../auth/google_sign_in_service.dart';

/// Metadata for a single backup file stored on Google Drive.
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

/// Uploads and restores app backups through the Google Drive API.
class GoogleDriveBackupService {
  GoogleDriveBackupService({
    required this.signInService,
    Logger? logger,
  }) : _logger = logger ?? Logger('GoogleDriveBackupService');

  static const String folderName = 'NexFitBackups';
  static const String filePrefix = 'nexfit_backup';

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

  Future<drive.File> _ensureBackupFolder(drive.DriveApi api) async {
    final drive.FileList result = await api.files.list(
      q: "name = '$folderName' and mimeType = "
          "'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      pageSize: 1,
    );

    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first;
    }

    return api.files.create(
      drive.File(
        name: folderName,
        mimeType: 'application/vnd.google-apps.folder',
      ),
    );
  }

  /// Uploads [content] as a backup file and returns the uploaded file id.
  Future<String> uploadBackup({
    required String content,
    required String fileName,
  }) async {
    final _DriveSession session = await _openSession();
    try {
      final drive.File folder = await _ensureBackupFolder(session.api);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(content));

      final drive.File uploaded = await session.api.files.create(
        drive.File(
          name: fileName,
          parents: [folder.id!],
          mimeType: 'application/json',
        ),
        uploadMedia: drive.Media(
          Stream.value(bytes),
          bytes.length,
        ),
      );
      _logger.info('Backup uploaded: ${uploaded.id}');
      return uploaded.id!;
    } on ApiRequestError catch (error) {
      throw BackupException(
        _mapDriveError(_statusOf(error)),
        code: 'drive_upload_failed',
      );
    } finally {
      session.client.close();
    }
  }

  /// Lists backups newest first.
  Future<List<BackupFileInfo>> listBackups() async {
    final _DriveSession session = await _openSession();
    try {
      final drive.FileList result = await session.api.files.list(
        q: "name contains '$filePrefix' and trashed = false",
        spaces: 'drive',
        orderBy: 'createdTime desc',
        pageSize: 10,
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

  /// Downloads the most recent backup. Returns null when none exist.
  Future<String?> downloadLatestBackup() async {
    final _DriveSession session = await _openSession();
    try {
      final List<BackupFileInfo> backups = await listBackups();
      if (backups.isEmpty) return null;

      final http.Response response = await session.client.get(
        Uri.parse(
          'https://www.googleapis.com/drive/v3/files/'
          '${backups.first.id}?alt=media',
        ),
      );
      if (response.statusCode != 200) {
        throw BackupException(
          _mapDriveError(response.statusCode),
          code: 'drive_download_failed',
        );
      }
      return utf8.decode(response.bodyBytes);
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
