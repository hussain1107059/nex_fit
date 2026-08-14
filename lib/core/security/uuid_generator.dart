import 'dart:math';

/// Cryptographically strong UUID v4 generation used for sync identity.
///
/// Centralised so the migration backfill, the device id and the sync event
/// outbox all produce the same format. No external dependency.
class UuidGenerator {
  UuidGenerator._();

  static final Random _random = Random.secure();

  /// Returns a RFC 4122 version 4 UUID string, e.g.
  /// `f47ac10b-58cc-4372-a567-0e02b2c3d479`.
  static String v4() {
    final List<int> bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    final String hex = bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}