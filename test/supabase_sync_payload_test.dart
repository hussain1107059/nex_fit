import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/data/services/sync/supabase_sync_transport.dart';

/// Regression test for the `sync_changes.payload` (jsonb) decoding in
/// [SupabaseSyncTransport.pull].
///
/// PostgREST returns jsonb columns as decoded JSON values, so supabase-dart
/// hands the payload over as a `Map`, not a `String`. The old `as String?`
/// cast threw a TypeError on every real change row, which escaped the
/// PostgrestException handler, aborted the pull before the cursor advanced and
/// left every outbox event pending with an error toast.
void main() {
  group('SupabaseSyncTransport.decodePayloadValue', () {
    test('accepts a decoded jsonb Map (PostgREST shape)', () {
      final Map<String, Object?> result = SupabaseSyncTransport
          .decodePayloadValue(<String, Object?>{
            'id': 'a1b2c3d4-1111-4222-8333-444455556666',
            'weight_kg': 72.5,
            'note': 'evening weigh-in',
            'logged_at': '2026-08-19T14:00:00.000Z',
            'user_id': 'u-1',
            'row_version': 1,
          });

      expect(result['weight_kg'], 72.5);
      expect(result['note'], 'evening weigh-in');
      expect(result['logged_at'], '2026-08-19T14:00:00.000Z');
    });

    test('accepts a JSON String payload (legacy/text transports)', () {
      final Map<String, Object?> result = SupabaseSyncTransport
          .decodePayloadValue('{"id":"x","weight_kg":70.5}');

      expect(result['weight_kg'], 70.5);
      expect(result['id'], 'x');
    });

    test('returns an empty map for null, numbers and malformed JSON', () {
      expect(SupabaseSyncTransport.decodePayloadValue(null), isEmpty);
      expect(SupabaseSyncTransport.decodePayloadValue(42), isEmpty);
      expect(SupabaseSyncTransport.decodePayloadValue('not json'), isEmpty);
      expect(
        SupabaseSyncTransport.decodePayloadValue(<Object>[1, 2, 3]),
        isEmpty,
      );
    });

    test('does not throw on a dynamic Map<String, dynamic> (supabase decode)',
        () {
      final dynamic raw = <String, dynamic>{
        'id': 'a1b2c3d4-1111-4222-8333-444455556666',
        'weight_kg': 70.5,
        'note': null,
      };
      final Map<String, Object?> result =
          SupabaseSyncTransport.decodePayloadValue(raw);
      expect(result['id'], 'a1b2c3d4-1111-4222-8333-444455556666');
      expect(result['weight_kg'], 70.5);
      expect(result.containsKey('note'), isTrue);
    });
  });
}