import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/errors/app_exception.dart';
import 'package:nexfit/data/services/backup/backup_encryption_service.dart';
import 'package:nexfit/data/services/backup/backup_packaging_service.dart';
import 'package:nexfit/data/services/storage/secure_storage_service.dart';
import 'package:nexfit/domain/entities/backup_metadata.dart';

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
  late BackupEncryptionService encryption;
  late BackupPackagingService packaging;
  late Map<String, String> store;

  setUp(() {
    store = <String, String>{};
    encryption = BackupEncryptionService(storage: _FakeStorage(store));
    packaging = BackupPackagingService(encryption: encryption);
  });

  test('generates and persists a single 32-byte key', () async {
    final Uint8List first = await encryption.getOrCreateKey();
    final Uint8List second = await encryption.getOrCreateKey();

    expect(first.length, 32);
    expect(first, second);
    expect(store, contains('nexfit.backup.key'));
  });

  test('encrypts and decrypts arbitrary bytes', () async {
    final Uint8List key = await encryption.getOrCreateKey();
    final Uint8List payload = Uint8List.fromList(
      List<int>.generate(2048, (int index) => index % 256),
    );

    final Uint8List blob = encryption.encrypt(payload, key);
    expect(blob.length, greaterThan(payload.length));

    final Uint8List restored = encryption.decrypt(blob, key);
    expect(restored, payload);
  });

  test('decryption fails with a wrong key', () async {
    final Uint8List key = await encryption.getOrCreateKey();
    final Uint8List blob = encryption.encrypt(
      Uint8List.fromList(<int>[1, 2, 3, 4]),
      key,
    );

    final Uint8List wrongKey = Uint8List.fromList(
      List<int>.generate(32, (int index) => index + 1),
    );
    expect(
      () => encryption.decrypt(blob, wrongKey),
      throwsA(isA<BackupException>()),
    );
  });

  test('package + readMetadata + unpack round trip', () async {
    final Uint8List key = await encryption.getOrCreateKey();
    final Uint8List dbBytes = Uint8List.fromList(
      List<int>.generate(4096, (int index) => (index * 7) % 256),
    );
    final BackupMetadata metadata = BackupMetadata(
      createdAt: DateTime(2026, 8, 1, 12, 30),
      appVersion: '1.0.0',
      databaseVersion: 12,
      deviceName: 'Pixel 7',
    );

    final Uint8List file = await packaging.package(
      dbBytes: dbBytes,
      metadata: metadata,
    );

    final BackupMetadata header = packaging.readMetadata(file);
    expect(header.appVersion, '1.0.0');
    expect(header.databaseVersion, 12);
    expect(header.deviceName, 'Pixel 7');
    expect(header.createdAt, metadata.createdAt);
    expect(header.checksum, isNotNull);
    expect(header.rawSizeBytes, dbBytes.length);

    final Uint8List restored = await packaging.unpack(
      fileBytes: file,
      key: key,
    );
    expect(restored, dbBytes);
  });

  test('rejects a foreign file and a corrupted payload', () async {
    final Uint8List key = await encryption.getOrCreateKey();
    expect(
      () => packaging.readMetadata(Uint8List.fromList(<int>[1, 2, 3, 4, 5])),
      throwsA(isA<BackupException>()),
    );

    final Uint8List file = await packaging.package(
      dbBytes: Uint8List.fromList(<int>[9, 9, 9]),
      metadata: BackupMetadata(
        createdAt: DateTime.now(),
        appVersion: '1.0.0',
        databaseVersion: 12,
        deviceName: 'test',
      ),
    );

    final Uint8List tampered = Uint8List.fromList(file);
    tampered[tampered.length - 5] ^= 0xFF;
    await expectLater(
      packaging.unpack(fileBytes: tampered, key: key),
      throwsA(isA<BackupException>()),
    );
  });
}
