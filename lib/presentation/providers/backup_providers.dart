import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../data/services/backup/backup_service.dart';
import '../../domain/entities/backup_history.dart';
import '../../domain/entities/backup_preview.dart';
import '../../domain/entities/common_enums.dart';
import '../../domain/entities/remote_backup_file.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';
import 'dashboard_providers.dart';
import 'profile_providers.dart';
import 'reminder_providers.dart';
import 'settings_providers.dart';

/// What a backup operation is currently doing.
enum BackupActivity { none, creating, restoring, deleting }

/// UI state for the backup module.
class BackupUiState {
  const BackupUiState({
    this.activity = BackupActivity.none,
    this.progress = 0,
    this.errorKey,
  });

  final BackupActivity activity;
  final double progress;
  final String? errorKey;

  bool get isBusy => activity != BackupActivity.none;

  BackupUiState copyWith({
    BackupActivity? activity,
    double? progress,
    String? errorKey,
    bool clearError = false,
  }) {
    return BackupUiState(
      activity: activity ?? this.activity,
      progress: progress ?? this.progress,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
    );
  }
}

/// Whether a Drive session is available for the current user.
final driveConnectedProvider = FutureProvider<bool>((ref) {
  return ref.watch(backupServiceProvider).isDriveConnected();
});

/// Backups currently stored in the Drive AppData folder (newest first).
final remoteBackupsProvider =
    FutureProvider.autoDispose<List<RemoteBackupFile>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return <RemoteBackupFile>[];
  return ref.watch(backupServiceProvider).listBackups();
});

/// Local records of backup attempts, newest first.
final backupHistoryProvider = FutureProvider<List<BackupHistory>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return <BackupHistory>[];
  return ref.watch(backupHistoryRepositoryProvider).getByUserId(user.id);
});

/// Drives manual backup, restore and delete operations with live progress.
class BackupController extends Notifier<BackupUiState> {
  @override
  BackupUiState build() => const BackupUiState();

  BackupService get _service => ref.read(backupServiceProvider);

  String? get _userId {
    final user = ref.read(currentUserProvider);
    if (user == null || !user.isSignedIn) return null;
    return user.id;
  }

  /// Creates a full encrypted backup of the local database.
  Future<void> createBackup({BackupType type = BackupType.manual}) async {
    final String? userId = _userId;
    if (userId == null) {
      throw const BackupException('backupNoUser', code: 'no_user');
    }
    state = const BackupUiState(
      activity: BackupActivity.creating,
      progress: 0,
    );
    try {
      await _service.createBackup(
        userId: userId,
        type: type,
        onProgress: (double progress) {
          state = state.copyWith(progress: progress);
        },
      );
      state = const BackupUiState(activity: BackupActivity.none, progress: 1);
      _invalidateAfterChange();
    } catch (error) {
      state = BackupUiState(errorKey: _messageOf(error));
      rethrow;
    }
  }

  /// Restores the local database from [file], replacing the current data.
  Future<void> restoreBackup(RemoteBackupFile file) async {
    state = const BackupUiState(activity: BackupActivity.restoring, progress: 0);
    try {
      await _service.restoreBackup(
        file: file,
        onProgress: (double progress) {
          state = state.copyWith(progress: progress);
        },
      );
      state = const BackupUiState(activity: BackupActivity.none, progress: 1);
      _invalidateAfterRestore();
    } catch (error) {
      state = BackupUiState(errorKey: _messageOf(error));
      rethrow;
    }
  }

  Future<void> deleteBackup(RemoteBackupFile file) async {
    state = const BackupUiState(activity: BackupActivity.deleting, progress: 0);
    try {
      await _service.deleteBackup(file.id);
      state = const BackupUiState(activity: BackupActivity.none, progress: 1);
      ref.invalidate(remoteBackupsProvider);
      ref.invalidate(backupHistoryProvider);
    } catch (error) {
      state = BackupUiState(errorKey: _messageOf(error));
      rethrow;
    }
  }

  Future<BackupPreview> previewBackup(RemoteBackupFile file) =>
      _service.previewBackup(file);

  /// Classifies how risky it is to restore [preview] over the current data.
  BackupRestoreRisk restoreRisk(
    BackupPreview preview, {
    required DateTime? lastBackupAt,
  }) {
    if (preview.metadata.databaseVersion > AppConstants.databaseVersion) {
      return BackupRestoreRisk.fromNewerVersion;
    }
    final bool fromOlder =
        preview.metadata.databaseVersion < AppConstants.databaseVersion;
    final bool losesRecent =
        lastBackupAt != null && preview.metadata.createdAt.isBefore(lastBackupAt);

    if (losesRecent) return BackupRestoreRisk.losesRecentData;
    if (fromOlder) return BackupRestoreRisk.fromOlderVersion;
    return BackupRestoreRisk.none;
  }

  /// Signs the user out of Drive (backups on Drive stay untouched).
  Future<void> signOutFromDrive() async {
    await _service.signOutFromDrive();
    ref.invalidate(driveConnectedProvider);
    ref.invalidate(remoteBackupsProvider);
  }

  void _invalidateAfterChange() {
    ref.invalidate(remoteBackupsProvider);
    ref.invalidate(backupHistoryProvider);
    ref.invalidate(settingsControllerProvider);
    ref.invalidate(driveConnectedProvider);
  }

  void _invalidateAfterRestore() {
    ref.invalidate(currentUserProvider);
    ref.invalidate(dashboardControllerProvider);
    ref.invalidate(settingsControllerProvider);
    ref.invalidate(profileControllerProvider);
    ref.invalidate(profileSettingsProvider);
    ref.invalidate(databaseSizeProvider);
    ref.invalidate(imageCacheSizeProvider);
    ref.invalidate(backupHistoryProvider);
    ref.invalidate(remoteBackupsProvider);
    unawaited(rescheduleRemindersInContainer(ref.container));
  }

  String _messageOf(Object error) {
    if (error is AppException) return error.message;
    return 'backupFailed';
  }
}

final backupControllerProvider =
    NotifierProvider<BackupController, BackupUiState>(BackupController.new);
