import 'package:equatable/equatable.dart';

/// Plaintext metadata describing one backup. Stored inside the backup header
/// so it can be previewed without decrypting the payload.
class BackupMetadata extends Equatable {
  const BackupMetadata({
    required this.createdAt,
    required this.appVersion,
    required this.databaseVersion,
    required this.deviceName,
    this.rawSizeBytes,
    this.checksum,
  });

  final DateTime createdAt;
  final String appVersion;
  final int databaseVersion;
  final String deviceName;

  /// Size of the original (uncompressed) database bytes.
  final int? rawSizeBytes;

  /// SHA-256 of the original database bytes; used to verify a restore.
  final String? checksum;

  BackupMetadata copyWith({
    DateTime? createdAt,
    String? appVersion,
    int? databaseVersion,
    String? deviceName,
    int? rawSizeBytes,
    String? checksum,
  }) {
    return BackupMetadata(
      createdAt: createdAt ?? this.createdAt,
      appVersion: appVersion ?? this.appVersion,
      databaseVersion: databaseVersion ?? this.databaseVersion,
      deviceName: deviceName ?? this.deviceName,
      rawSizeBytes: rawSizeBytes ?? this.rawSizeBytes,
      checksum: checksum ?? this.checksum,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'createdAt': createdAt.toIso8601String(),
      'appVersion': appVersion,
      'databaseVersion': databaseVersion,
      'deviceName': deviceName,
      'rawSizeBytes': rawSizeBytes,
      'checksum': checksum,
    };
  }

  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    return BackupMetadata(
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      appVersion: json['appVersion'] as String? ?? '',
      databaseVersion: json['databaseVersion'] as int? ?? 0,
      deviceName: json['deviceName'] as String? ?? '',
      rawSizeBytes: json['rawSizeBytes'] as int?,
      checksum: json['checksum'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        createdAt,
        appVersion,
        databaseVersion,
        deviceName,
        rawSizeBytes,
        checksum,
      ];
}
