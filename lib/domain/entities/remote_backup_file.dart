import 'package:equatable/equatable.dart';

/// A single backup file stored on Google Drive.
class RemoteBackupFile extends Equatable {
  const RemoteBackupFile({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final int sizeBytes;

  @override
  List<Object?> get props => [id, name, createdAt, sizeBytes];
}
