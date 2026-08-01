import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/constants/app_constants.dart';
import 'package:nexfit/data/services/security/encryption_service.dart';
import 'package:nexfit/data/services/security/key_manager.dart';
import 'package:nexfit/data/services/storage/secure_storage_service.dart';

/// In-memory [SecureStorageService] so the key manager works without a
/// platform channel.
class _FakeStorage extends SecureStorageService {
  _FakeStorage(this.values);

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<bool> contains(String key) async => values.containsKey(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

void main() {
  late KeyManager keyManager;
  late Map<String, String> store;
  final EncryptionService service = EncryptionService();

  setUp(() {
    store = <String, String>{};
    keyManager = KeyManager(storage: _FakeStorage(store));
    FieldEncryption.disable();
  });

  group('EncryptionService', () {
    test('AES-256-GCM round-trips bytes', () {
      final List<int> key = List<int>.generate(32, (int index) => index);
      final Uint8List plain = Uint8List.fromList(utf8.encode('hello world'));

      final Uint8List blob = service.encryptBytes(plain, Uint8List.fromList(key));
      final Uint8List? restored = service.tryDecryptBytes(
        blob,
        Uint8List.fromList(key),
      );

      expect(restored, isNotNull);
      expect(utf8.decode(restored!), 'hello world');
    });

    test('decrypting with the wrong key returns null', () {
      final Uint8List key = Uint8List.fromList(
        List<int>.generate(32, (int index) => index),
      );
      final Uint8List wrong = Uint8List.fromList(
        List<int>.generate(32, (int index) => index + 1),
      );
      final Uint8List blob = service.encryptBytes(
        Uint8List.fromList(utf8.encode('secret')),
        key,
      );

      expect(service.tryDecryptBytes(blob, wrong), isNull);
    });
  });

  group('FieldEncryption', () {
    test('encrypts and decrypts via the facade when enabled', () async {
      await FieldEncryption.configure(keyManager: keyManager, enabled: true);
      expect(FieldEncryption.enabled, isTrue);

      const String plain = 'Very private body note';
      final String encrypted = FieldEncryption.encrypt(plain)!;

      expect(encrypted, isNot(plain));
      expect(encrypted, startsWith(AppConstants.encryptionFieldPrefix));
      expect(FieldEncryption.decrypt(encrypted), plain);
    });

    test('passes plaintext through when disabled', () async {
      await FieldEncryption.configure(keyManager: keyManager, enabled: false);

      expect(FieldEncryption.encrypt('plain text'), 'plain text');
      expect(FieldEncryption.decrypt('plain text'), 'plain text');
    });

    test('key rotation keeps old rows decryptable', () async {
      await FieldEncryption.configure(keyManager: keyManager, enabled: true);

      final String legacy = FieldEncryption.encrypt('legacy value')!;

      await keyManager.rotateKey();
      await FieldEncryption.configure(keyManager: keyManager, enabled: true);

      // New writes use the active key and round-trip.
      final String fresh = FieldEncryption.encrypt('fresh value')!;
      expect(FieldEncryption.decrypt(fresh), 'fresh value');

      // The previous key version is still readable.
      expect(FieldEncryption.decrypt(legacy), 'legacy value');
    });
  });

  group('KeyManager', () {
    test('creates a stable active key and lists every version', () async {
      final List<int> first = await keyManager.getOrCreateActiveKey();
      final List<int> second = await keyManager.getOrCreateActiveKey();

      expect(first.length, AppConstants.encryptionKeyLengthBytes);
      expect(first, second);

      final List<List<int>> all = await keyManager.allKeys();
      expect(all, hasLength(1));
      expect(all.first, first);
    });

    test('rotateKey bumps the version while keeping old keys', () async {
      await keyManager.getOrCreateActiveKey();
      final int rotated = await keyManager.rotateKey();

      expect(rotated, 2);
      expect(await keyManager.activeVersion(), 2);
      expect(await keyManager.allKeys(), hasLength(2));
    });
  });
}
