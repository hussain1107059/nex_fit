import 'package:equatable/equatable.dart';

import 'common_enums.dart';

/// A record of one backup attempt (manual or automatic).
class BackupHistory extends Equatable {
  const BackupHistory({
    this.id,
    required this.userId,
    required this.backupType,
    this.backupSizeBytes,
    this.fileName,
    this.fileId,
    required this.status,
    this.errorMessage,
    this.durationMs,
    required this.createdAt,
  });

  final int? id;
  final String userId;
  final BackupType backupType;
  final int? backupSizeBytes;
  final String? fileName;
  final String? fileId;
  final BackupStatus status;
  final String? errorMessage;
  final int? durationMs;
  final DateTime createdAt;

  BackupHistory copyWith({
    int? id,
    String? userId,
    BackupType? backupType,
    int? backupSizeBytes,
    String? fileName,
    String? fileId,
    BackupStatus? status,
    String? errorMessage,
    int? durationMs,
    DateTime? createdAt,
  }) {
    return BackupHistory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      backupType: backupType ?? this.backupType,
      backupSizeBytes: backupSizeBytes ?? this.backupSizeBytes,
      fileName: fileName ?? this.fileName,
      fileId: fileId ?? this.fileId,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        backupType,
        backupSizeBytes,
        fileName,
        fileId,
        status,
        errorMessage,
        durationMs,
        createdAt,
      ];
}
