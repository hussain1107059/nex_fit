import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/pointycastle.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../storage/secure_storage_service.dart';

/// AES-256-GCM encryption for Google Drive backups.
///
/// The 32-byte key is generated once and kept in the OS keychain through
/// [SecureStorageService]; it is never stored on Drive or in the app database.
class BackupEncryptionService {
  BackupEncryptionService({
    required this.storage,
    Logger? logger,
  }) : _logger = logger ?? Logger('BackupEncryptionService');

  static const int keyLengthBytes = 32;
  static const int nonceLengthBytes = 12;
  static const int tagLengthBits = 128;

  final SecureStorageService storage;
  final Logger _logger;

  /// Returns the persistent 32-byte backup key, creating and persisting it on
  /// first use.
  Future<Uint8List> getOrCreateKey() async {
    final String? existing = await storage.read(AppConstants.backupKeyStorageKey);
    if (existing != null) {
      try {
        return Uint8List.fromList(base64Decode(existing));
      } catch (_) {
        _logger.warning('Stored backup key is invalid; replacing it');
      }
    }

    final Random random = Random.secure();
    final Uint8List key = Uint8List.fromList(
      List<int>.generate(keyLengthBytes, (_) => random.nextInt(256)),
    );
    await storage.write(
      AppConstants.backupKeyStorageKey,
      base64Encode(key),
    );
    return key;
  }

  /// Encrypts [plaintext]. The returned blob is nonce(12) || ciphertext || tag.
  Uint8List encrypt(Uint8List plaintext, Uint8List key) {
    if (key.length != keyLengthBytes) {
      throw const BackupException('backupInvalidKey', code: 'invalid_key');
    }

    final Random random = Random.secure();
    final Uint8List nonce = Uint8List.fromList(
      List<int>.generate(nonceLengthBytes, (_) => random.nextInt(256)),
    );

    final GCMBlockCipher cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      true,
      AEADParameters<KeyParameter>(
        KeyParameter(key),
        tagLengthBits,
        nonce,
        Uint8List(0),
      ),
    );

    final Uint8List out = Uint8List(
      cipher.getOutputSize(plaintext.length),
    );
    int written = cipher.processBytes(plaintext, 0, plaintext.length, out, 0);
    written += cipher.doFinal(out, written);

    final Uint8List blob = Uint8List(nonceLengthBytes + written);
    blob.setRange(0, nonceLengthBytes, nonce);
    blob.setRange(nonceLengthBytes, blob.length, out);
    return blob;
  }

  /// Decrypts a blob produced by [encrypt]. Throws on a wrong key or a
  /// corrupted payload.
  Uint8List decrypt(Uint8List blob, Uint8List key) {
    if (blob.length < nonceLengthBytes + 16 || key.length != keyLengthBytes) {
      throw const BackupException('backupCorrupted', code: 'corrupted');
    }

    final Uint8List nonce = Uint8List.sublistView(blob, 0, nonceLengthBytes);
    final Uint8List ciphertext = Uint8List.sublistView(blob, nonceLengthBytes);

    final GCMBlockCipher cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      false,
      AEADParameters<KeyParameter>(
        KeyParameter(key),
        tagLengthBits,
        nonce,
        Uint8List(0),
      ),
    );

    try {
      final Uint8List out = Uint8List(
        cipher.getOutputSize(ciphertext.length),
      );
      int written = cipher.processBytes(
        ciphertext,
        0,
        ciphertext.length,
        out,
        0,
      );
      written += cipher.doFinal(out, written);
      return Uint8List.sublistView(out, 0, written);
    } on Exception {
      throw const BackupException('backupCorrupted', code: 'corrupted');
    }
  }
}
