import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/data/services/security/pin_hasher.dart';

/// Security hardening tests for the app-lock PIN hashing (PROMPT 38):
/// versioned PBKDF2-HMAC-SHA256 with a random salt, plus backward-compatible
/// verification and in-place upgrade of the legacy static-salt scheme.
void main() {
  group('PinHasher', () {
    test('hashPin produces a versioned, salted PBKDF2 hash', () {
      final PinHasher hasher = PinHasher();
      final String stored = hasher.hashPin('1234');

      expect(stored, startsWith('nk2:'));
      final List<String> parts = stored.replaceFirst('nk2:', '').split(':');
      expect(parts.length, 3);
      expect(int.parse(parts[0]), greaterThan(0));
      // Salt must decode to 16 random bytes.
      expect(base64.decode(parts[1]).length, 16);
      expect(base64.decode(parts[2]).length, 32);
    });

    test('two hashes of the same PIN differ (random salt)', () {
      final PinHasher hasher = PinHasher();
      expect(hasher.hashPin('1234'), isNot(hasher.hashPin('1234')));
    });

    test('verifyPin accepts the correct PIN and rejects a wrong one', () {
      final PinHasher hasher = PinHasher();
      final String stored = hasher.hashPin('9876');

      expect(hasher.verifyPin('9876', stored), isTrue);
      expect(hasher.verifyPin('9875', stored), isFalse);
      expect(hasher.verifyPin('', stored), isFalse);
      expect(hasher.verifyPin('9876', ''), isFalse);
    });

    test('verifyPin still accepts the legacy static-salt SHA-256 hash', () {
      final PinHasher hasher = PinHasher();
      const String legacySalt = 'nexfit.app.lock.v1';
      final String legacy = sha256
          .convert(utf8.encode('$legacySalt:1234'))
          .toString();

      expect(PinHasher.isVersioned(legacy), isFalse);
      expect(hasher.verifyPin('1234', legacy), isTrue);
      expect(hasher.verifyPin('1235', legacy), isFalse);
    });

    test('verifyPin rejects a tampered versioned hash', () {
      final PinHasher hasher = PinHasher();
      final String stored = hasher.hashPin('1111');
      final List<String> parts = stored.split(':');

      // Corrupt the hash component.
      final String badHash = '${parts[0]}:${parts[1]}:'
          '${base64.encode(List<int>.filled(32, 0))}';
      expect(hasher.verifyPin('1111', badHash), isFalse);

      // Corrupt the salt component.
      final String badSalt = '${parts[0]}:'
          '${base64.encode(List<int>.filled(16, 1))}:${parts[2]}';
      expect(hasher.verifyPin('1111', badSalt), isFalse);

      // Malformed versions.
      expect(hasher.verifyPin('1111', 'nk2:not-a-number:salt:hash'), isFalse);
      expect(hasher.verifyPin('1111', 'nk2:120000'), isFalse);
      expect(hasher.verifyPin('1111', 'nk2:120000:!!!:!!!'), isFalse);
    });

    test('isVersioned distinguishes the new format from legacy', () {
      expect(PinHasher.isVersioned('nk2:120000:abc:def'), isTrue);
      expect(
        PinHasher.isVersioned(
          sha256.convert(utf8.encode('x')).toString(),
        ),
        isFalse,
      );
      expect(PinHasher.isVersioned(''), isFalse);
    });
  });
}