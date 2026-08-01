import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';

import '../../../core/constants/app_constants.dart';
import '../storage/secure_storage_service.dart';

/// Manages the versioned field-encryption keys stored in the OS keychain.
///
/// A fresh 32-byte key is created on first use. `rotateKey` generates a new
/// version and points the active pointer at it while keeping the previous key
/// around so legacy rows can still be decrypted. Keys never leave the secure
/// storage and are never written to the app database or to backups.
class KeyManager {
  KeyManager({
    required this.storage,
    Logger? logger,
  }) : _logger = logger ?? Logger('KeyManager');

  final SecureStorageService storage;
  final Logger _logger;

  static const int keyLengthBytes = AppConstants.encryptionKeyLengthBytes;

  String _storageKey(int version) =>
      '${AppConstants.encryptionKeyPrefix}v$version';

  /// Returns the active key version number.
  Future<int> activeVersion() async {
    final String? raw = await storage.read(
      AppConstants.encryptionActiveKeyStorageKey,
    );
    return int.tryParse(raw ?? '') ?? 0;
  }

  /// Returns the active 32-byte key, creating it on first use.
  Future<List<int>> getOrCreateActiveKey() async {
    final int version = await activeVersion();
    if (version > 0) {
      final String? existing = await storage.read(_storageKey(version));
      if (existing != null) {
        try {
          return base64Decode(existing);
        } catch (_) {
          _logger.warning(
            'Stored encryption key v$version is invalid; replacing it',
          );
        }
      }
    }

    final List<int> key = _generateKey();
    final int nextVersion = version + 1;
    await storage.write(_storageKey(nextVersion), base64Encode(key));
    await storage.write(
      AppConstants.encryptionActiveKeyStorageKey,
      '$nextVersion',
    );
    return key;
  }

  /// All known key versions (oldest first) so legacy rows can be decrypted.
  Future<List<List<int>>> allKeys() async {
    final List<List<int>> keys = <List<int>>[];
    final int active = await activeVersion();
    for (int version = 1; version <= active; version++) {
      final String? raw = await storage.read(_storageKey(version));
      if (raw == null) continue;
      try {
        keys.add(base64Decode(raw));
      } catch (_) {
        _logger.warning('Skipping unreadable encryption key v$version');
      }
    }
    if (keys.isEmpty) {
      keys.add(await getOrCreateActiveKey());
    }
    return keys;
  }

  /// Rotates the active key to a freshly generated version. Previous keys are
  /// kept so existing encrypted rows remain decryptable.
  Future<int> rotateKey() async {
    final List<int> key = _generateKey();
    final int version = (await activeVersion()) + 1;
    await storage.write(_storageKey(version), base64Encode(key));
    await storage.write(
      AppConstants.encryptionActiveKeyStorageKey,
      '$version',
    );
    _logger.info('Field-encryption key rotated to version $version');
    return version;
  }

  List<int> _generateKey() {
    final Random random = Random.secure();
    return List<int>.generate(
      keyLengthBytes,
      (_) => random.nextInt(256),
    );
  }
}
