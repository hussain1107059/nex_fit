import 'dart:convert';

import '../../domain/entities/activity.dart';
import 'model_codec.dart';

/// Maps [ActivitySession] to and from rows in the `activity_session` table.
class ActivitySessionModel {
  ActivitySessionModel._();

  static const String table = 'activity_session';

  static Map<String, Object?> toMap(ActivitySession session) {
    return <String, Object?>{
      'id': session.id,
      'user_id': session.userId,
      'activity_type': session.type.value,
      'started_at': ModelCodec.epochMs(session.startedAt),
      'ended_at': ModelCodec.epochMs(session.endedAt),
      'duration_seconds': session.durationSeconds,
      'distance_meters': session.distanceMeters,
      'calories_burned': session.caloriesBurned,
      'elevation_gain_meters': session.elevationGainMeters,
      'avg_speed_mps': session.avgSpeedMps,
      'max_speed_mps': session.maxSpeedMps,
      'route_json': _encodeRoute(session.route),
      'note': session.note,
      'created_at': ModelCodec.epochMs(session.createdAt),
    };
  }

  static ActivitySession fromMap(Map<String, Object?> row) {
    return ActivitySession(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      type: ActivityType.fromValue(row['activity_type'] as String? ?? ''),
      startedAt:
          ModelCodec.fromEpochMs(row['started_at'] as int?) ?? DateTime.now(),
      endedAt: ModelCodec.fromEpochMs(row['ended_at'] as int?),
      durationSeconds: ModelCodec.toInt(row['duration_seconds']),
      distanceMeters: ModelCodec.toDouble(row['distance_meters']) ?? 0,
      caloriesBurned: ModelCodec.toDouble(row['calories_burned']) ?? 0,
      elevationGainMeters:
          ModelCodec.toDouble(row['elevation_gain_meters']) ?? 0,
      avgSpeedMps: ModelCodec.toDouble(row['avg_speed_mps']) ?? 0,
      maxSpeedMps: ModelCodec.toDouble(row['max_speed_mps']) ?? 0,
      route: _decodeRoute(row['route_json'] as String?),
      note: row['note'] as String?,
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
    );
  }

  static String? _encodeRoute(List<ActivityPoint> route) {
    if (route.isEmpty) return null;
    return jsonEncode(
      route.map((ActivityPoint point) => point.toStorage()).toList(),
    );
  }

  static List<ActivityPoint> _decodeRoute(String? raw) {
    if (raw == null || raw.isEmpty) return const <ActivityPoint>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return const <ActivityPoint>[];
      final List<ActivityPoint> points = <ActivityPoint>[];
      for (final Object? entry in decoded) {
        try {
          points.add(ActivityPoint.fromStorage(entry));
        } on FormatException {
          continue;
        } on TypeError {
          continue;
        }
      }
      return points;
    } on FormatException {
      return const <ActivityPoint>[];
    }
  }
}
