import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/pointycastle.dart';

/// Hashes and verifies the app-lock PIN.
///
/// PIN hashes are stored in the local `app_settings` table, which is
/// unencrypted SQFlite. They must therefore be verifiable but not cheaply
/// reversible. The current scheme is PBKDF2-HMAC-SHA256 with a random 16-byte
/// salt and a fixed iteration count, stored as the versioned string
/// `nk2-iterations-saltB64-hashB64`. A legacy SHA-256-with-static-salt format
/// (from earlier builds) is still accepted on verify so existing users are not
/// locked out, and is upgraded in place on the next successful unlock.
class PinHasher {
  PinHasher({Random? random}) : _random = random ?? Random.secure();

  static const String _versionedPrefix = 'nk2:';
  static const int _saltLengthBytes = 16;
  static const int _keyLengthBytes = 32;
  static const int _iterations = 120000;

  /// Static salt prepended to the PIN by the legacy (pre-PBKDF2) scheme so the
  /// digest is not a plain SHA-256 of the raw digits.
  static const String _legacySalt = 'nexfit.app.lock.v1';

  final Random _random;

  /// Returns true when [stored] is a current-format versioned hash.
  static bool isVersioned(String stored) =>
      stored.startsWith(_versionedPrefix);

  /// Hashes [pin] into the versioned PBKDF2 format.
  String hashPin(String pin) {
    final Uint8List salt = Uint8List.fromList(
      List<int>.generate(_saltLengthBytes, (_) => _random.nextInt(256)),
    );
    return _deriveVersioned(pin, salt);
  }

  /// Verifies [pin] against [stored]. Accepts both the current versioned
  /// PBKDF2 format and the legacy static-salt SHA-256 format (returns true for
  /// a legacy match so existing installs keep working).
  bool verifyPin(String pin, String stored) {
    if (stored.isEmpty) return false;
    if (isVersioned(stored)) {
      return _verifyVersioned(pin, stored);
    }
    return _hashLegacy(pin) == stored;
  }

  String _deriveVersioned(String pin, Uint8List salt) {
    final Uint8List key = _pbkdf2(pin, salt);
    return '$_versionedPrefix$_iterations:'
        '${base64.encode(salt)}:${base64.encode(key)}';
  }

  bool _verifyVersioned(String pin, String stored) {
    final List<String> parts = stored
        .replaceFirst(_versionedPrefix, '')
        .split(':');
    if (parts.length != 3) return false;
    final int? iterations = int.tryParse(parts[0]);
    if (iterations == null || iterations <= 0) return false;
    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = base64.decode(parts[1]);
      expected = base64.decode(parts[2]);
    } on FormatException {
      return false;
    }
    final Uint8List actual = _pbkdf2(pin, salt, iterations: iterations);
    return _constantTimeEquals(actual, expected);
  }

  Uint8List _pbkdf2(String pin, Uint8List salt, {int? iterations}) {
    final PBKDF2KeyDerivator derivator = PBKDF2KeyDerivator(
      HMac(SHA256Digest(), 64),
    );
    derivator.init(
      Pbkdf2Parameters(
        salt,
        iterations ?? _iterations,
        _keyLengthBytes,
      ),
    );
    return derivator.process(Uint8List.fromList(utf8.encode(pin)));
  }

  String _hashLegacy(String pin) =>
      sha256.convert(utf8.encode('$_legacySalt:$pin')).toString();

  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}