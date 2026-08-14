import 'dart:convert';

import '../../../domain/entities/security_enums.dart';

/// Stable, versioned payload contract attached to every outbox event.
///
/// The payload carries everything a push transport needs to reconstruct the
/// remote write without a second local read, and it is the canonical envelope
/// the DAO migration phase will fill from each mutation. Serialised as a
/// JSON string in the `sync_event.payload` column.
///
/// Contract (v1):
/// ```json
/// {
///   "schema_version": 1,
///   "entity": "weight_log",
///   "record_id": "uuid-of-the-row",
///   "operation": "update",
///   "base_version": 3,
///   "data": { "weight_kg": 82.5, "logged_at": 1730000000000 }
/// }
/// ```
class SyncEventPayload {
  const SyncEventPayload({
    required this.entity,
    required this.recordId,
    required this.operation,
    required this.data,
    this.baseVersion = 0,
  });

  static const int schemaVersion = 1;

  final String entity;
  final String recordId;
  final SyncOperation operation;
  final Map<String, Object?> data;
  final int baseVersion;

  /// Encodes the payload to its stable JSON string form.
  String encode() => jsonEncode(<String, Object?>{
        'schema_version': schemaVersion,
        'entity': entity,
        'record_id': recordId,
        'operation': operation.name,
        'base_version': baseVersion,
        'data': data,
      });

  /// Parses [encoded]; returns null when the envelope is not a valid payload.
  static SyncEventPayload? tryDecode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final Map<String, dynamic> json =
          jsonDecode(encoded) as Map<String, dynamic>;
      final Map<String, dynamic> data =
          (json['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      return SyncEventPayload(
        entity: json['entity'] as String,
        recordId: json['record_id'] as String,
        operation: SyncOperation.fromName(json['operation'] as String?),
        baseVersion: (json['base_version'] as num?)?.toInt() ?? 0,
        data: data,
      );
    } catch (_) {
      return null;
    }
  }
}
