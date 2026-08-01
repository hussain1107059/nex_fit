import 'package:equatable/equatable.dart';

import 'backup_metadata.dart';
import 'remote_backup_file.dart';

/// A preview of a remote backup: the Drive file plus its plaintext metadata.
class BackupPreview extends Equatable {
  const BackupPreview({
    required this.file,
    required this.metadata,
  });

  final RemoteBackupFile file;
  final BackupMetadata metadata;

  @override
  List<Object?> get props => [file, metadata];
}
