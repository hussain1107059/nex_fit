import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/pointycastle.dart';

import '../../../core/constants/app_constants.dart';
import 'key_manager.dart';

/// AES-256-GCM primitives for field-level encryption.
///
/// Encrypted payloads are `nonce(12) || ciphertext || tag`. Unlike the backup
/// file encryption (which owns a single key), this service is key-agnostic:
/// callers choose which key version to use.
class EncryptionService {
  static const int keyLengthBytes = AppConstants.encryptionKeyLengthBytes;
  static const int nonceLengthBytes = AppConstants.encryptionNonceLengthBytes;
  static const int tagLengthBits = AppConstants.encryptionTagLengthBits;

  /// Encrypts [plaintext] into `nonce || ciphertext || tag`.
  Uint8List encryptBytes(Uint8List plaintext, Uint8List key) {
    if (key.length != keyLengthBytes) {
      throw ArgumentError('Invalid key length: ${key.length}');
    }

    final Random random = Random.secure();
    final Uint8List nonce = Uint8List.fromList(
      List<int>.generate(nonceLengthBytes, (_) => random.nextInt(256)),
    );

    final GCMBlockCipher cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      true,
      AEADParameters<KeyParameter>(KeyParameter(key), tagLengthBits, nonce, Uint8List(0)),
    );

    final Uint8List out = Uint8List(cipher.getOutputSize(plaintext.length));
    int written = cipher.processBytes(plaintext, 0, plaintext.length, out, 0);
    written += cipher.doFinal(out, written);

    final Uint8List blob = Uint8List(nonceLengthBytes + written);
    blob.setRange(0, nonceLengthBytes, nonce);
    blob.setRange(nonceLengthBytes, blob.length, out);
    return blob;
  }

  /// Decrypts a blob produced by [encryptBytes]. Returns null when the payload
  /// is malformed or the key is wrong.
  Uint8List? tryDecryptBytes(Uint8List blob, Uint8List key) {
    if (blob.length < nonceLengthBytes + 16 || key.length != keyLengthBytes) {
      return null;
    }

    final Uint8List nonce = Uint8List.sublistView(blob, 0, nonceLengthBytes);
    final Uint8List ciphertext = Uint8List.sublistView(blob, nonceLengthBytes);

    final GCMBlockCipher cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      false,
      AEADParameters<KeyParameter>(KeyParameter(key), tagLengthBits, nonce, Uint8List(0)),
    );

    try {
      final Uint8List out = Uint8List(cipher.getOutputSize(ciphertext.length));
      int written = cipher.processBytes(ciphertext, 0, ciphertext.length, out, 0);
      written += cipher.doFinal(out, written);
      return Uint8List.sublistView(out, 0, written);
    } on Exception {
      return null;
    }
  }
}

/// Static facade used by the data models so encryption stays invisible to the
/// domain layer.
///
/// Models call [encrypt] in `toMap` and [decrypt] in `fromMap`. When the
/// feature is disabled, the key is not loaded, or the value is not an
/// encrypted blob, values pass through unchanged - which keeps existing
/// plaintext rows (and rows restored from another device) readable.
class FieldEncryption {
  FieldEncryption._();

  static const String _prefix = AppConstants.encryptionFieldPrefix;

  static final EncryptionService _service = EncryptionService();
  static List<List<int>> _keys = const <List<int>>[];
  static bool _enabled = false;

  static bool get enabled => _enabled;

  /// Loads every known key version and enables/disables field encryption.
  static Future<void> configure({
    required KeyManager keyManager,
    required bool enabled,
  }) async {
    _keys = enabled ? await keyManager.allKeys() : const <List<int>>[];
    _enabled = enabled;
  }

  /// Disables the facade and drops the cached keys.
  static void disable() {
    _keys = const <List<int>>[];
    _enabled = false;
  }

  /// Encrypts [value], or returns it unchanged when encryption is off.
  static String? encrypt(String? value) {
    if (!_enabled || value == null || value.isEmpty || _keys.isEmpty) {
      return value;
    }
    final Uint8List plain = Uint8List.fromList(utf8.encode(value));
    final Uint8List blob = _service.encryptBytes(plain, Uint8List.fromList(_keys.last));
    return '$_prefix${base64Encode(blob)}';
  }

  /// Decrypts [value], falling back to the raw value when it is not an
  /// encrypted blob or none of the known keys match.
  static String? decrypt(String? value) {
    if (!_enabled || value == null || value.isEmpty) return value;
    if (!value.startsWith(_prefix)) return value;

    final Uint8List blob;
    try {
      blob = base64Decode(value.substring(_prefix.length));
    } catch (_) {
      return value;
    }

    for (final List<int> key in _keys.reversed) {
      final Uint8List? plain = _service.tryDecryptBytes(
        blob,
        Uint8List.fromList(key),
      );
      if (plain != null) {
        try {
          return utf8.decode(plain);
        } catch (_) {
          return value;
        }
      }
    }
    return value;
  }
}
