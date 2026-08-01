import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/backup_metadata.dart';
import 'backup_encryption_service.dart';

/// Assembles and parses the self-describing NexFit backup file format.
///
/// Layout (all integers big-endian):
/// ```
/// [0..7]    magic         "NXFBK001"
/// [8..9]    format version (uint16)
/// [10..13]  header length (uint32)
/// [14..h]   header JSON (UTF-8) -> BackupMetadata
/// [h..end]  encrypted blob: nonce(12) || AES-GCM(header, tag)
/// ```
/// The encrypted payload holds the zlib-compressed SQLite bytes.
class BackupPackagingService {
  BackupPackagingService({
    required this.encryption,
    Logger? logger,
  }) : _logger = logger ?? Logger('BackupPackagingService');

  static const int magicLength = 8;
  static const int versionLength = 2;
  static const int headerLengthLength = 4;
  static const int headerOffset = magicLength + versionLength + headerLengthLength;

  final BackupEncryptionService encryption;
  final Logger _logger;

  /// Builds a complete backup file from the raw database bytes.
  Future<Uint8List> package({
    required Uint8List dbBytes,
    required BackupMetadata metadata,
  }) async {
    final Uint8List key = await encryption.getOrCreateKey();

    final String checksum = sha256.convert(dbBytes).toString();
    final Uint8List compressed = _compress(dbBytes);
    final BackupMetadata fullMetadata = metadata.copyWith(
      checksum: checksum,
      rawSizeBytes: dbBytes.length,
    );

    final Uint8List encrypted = encryption.encrypt(compressed, key);
    return _assemble(fullMetadata, encrypted);
  }

  /// Reads only the plaintext header (no key required).
  BackupMetadata readMetadata(Uint8List fileBytes) {
    final _HeaderResult header = _parseHeader(fileBytes);
    return header.metadata;
  }

  /// Decrypts and decompresses a backup, verifying its integrity checksum.
  /// Returns the original raw SQLite bytes.
  Future<Uint8List> unpack({
    required Uint8List fileBytes,
    required Uint8List key,
  }) async {
    final _HeaderResult header = _parseHeader(fileBytes);

    final Uint8List encrypted = Uint8List.sublistView(
      fileBytes,
      header.encryptedOffset,
    );
    final Uint8List compressed;
    try {
      compressed = encryption.decrypt(encrypted, key);
    } on BackupException catch (error) {
      _logger.warning('Backup decryption failed: ${error.code}');
      throw const BackupException('backupDecryptFailed', code: 'decrypt_failed');
    }

    final Uint8List raw;
    try {
      raw = _decompress(compressed);
    } on Exception {
      throw const BackupException('backupCorrupted', code: 'corrupted');
    }

    final String checksum = sha256.convert(raw).toString();
    if (header.metadata.checksum != null &&
        checksum != header.metadata.checksum) {
      _logger.warning('Backup checksum mismatch');
      throw const BackupException('backupCorrupted', code: 'corrupted');
    }
    return raw;
  }

  Uint8List _compress(Uint8List bytes) {
    final List<int> level = ZLibEncoder(level: 6).convert(bytes);
    return Uint8List.fromList(level);
  }

  Uint8List _decompress(Uint8List bytes) => Uint8List.fromList(zlib.decode(bytes));

  Uint8List _assemble(BackupMetadata metadata, Uint8List encrypted) {
    final List<int> headerBytes = utf8.encode(jsonEncode(metadata.toJson()));
    final int totalLength =
        headerOffset + headerBytes.length + encrypted.length;
    final Uint8List out = Uint8List(totalLength);

    out.setRange(0, magicLength, utf8.encode(AppConstants.backupMagic));
    out[magicLength] = (AppConstants.backupFormatVersion >> 8) & 0xFF;
    out[magicLength + 1] = AppConstants.backupFormatVersion & 0xFF;
    out[magicLength + 2] = (headerBytes.length >> 24) & 0xFF;
    out[magicLength + 3] = (headerBytes.length >> 16) & 0xFF;
    out[magicLength + 4] = (headerBytes.length >> 8) & 0xFF;
    out[magicLength + 5] = headerBytes.length & 0xFF;

    out.setRange(headerOffset, headerOffset + headerBytes.length, headerBytes);
    out.setRange(headerOffset + headerBytes.length, out.length, encrypted);
    return out;
  }

  _HeaderResult _parseHeader(Uint8List fileBytes) {
    if (fileBytes.length < headerOffset + 2) {
      throw const BackupException('backupCorrupted', code: 'corrupted');
    }

    final String magic =
        String.fromCharCodes(fileBytes.sublist(0, magicLength));
    if (magic != AppConstants.backupMagic) {
      throw const BackupException('backupNotNexFit', code: 'not_nexfit');
    }

    final int formatVersion = (fileBytes[magicLength] << 8) | fileBytes[magicLength + 1];
    if (formatVersion != AppConstants.backupFormatVersion) {
      throw const BackupException('backupVersionUnsupported', code: 'unsupported');
    }

    final int headerLength =
        (fileBytes[magicLength + 2] << 24) |
        (fileBytes[magicLength + 3] << 16) |
        (fileBytes[magicLength + 4] << 8) |
        fileBytes[magicLength + 5];

    if (fileBytes.length < headerOffset + headerLength) {
      throw const BackupException('backupCorrupted', code: 'corrupted');
    }

    final String headerJson =
        utf8.decode(fileBytes.sublist(headerOffset, headerOffset + headerLength));
    final Map<String, dynamic> json = jsonDecode(headerJson) as Map<String, dynamic>;
    return _HeaderResult(
      metadata: BackupMetadata.fromJson(json),
      encryptedOffset: headerOffset + headerLength,
    );
  }
}

class _HeaderResult {
  const _HeaderResult({required this.metadata, required this.encryptedOffset});

  final BackupMetadata metadata;
  final int encryptedOffset;
}
