import '../../domain/entities/app_session.dart';
import 'model_codec.dart';

/// Maps [AppSession] to and from rows in the `sessions` table.
class AppSessionModel {
  AppSessionModel._();

  static const String table = 'sessions';

  static Map<String, Object?> toMap(AppSession session) {
    return <String, Object?>{
      'id': session.id,
      'user_id': session.userId,
      'token': session.token,
      'device_id': session.deviceId,
      'created_at': ModelCodec.epochMs(session.createdAt),
      'expires_at': ModelCodec.epochMs(session.expiresAt),
      'last_activity_at': ModelCodec.epochMs(session.lastActivityAt),
      'is_active': ModelCodec.boolToInt(session.isActive),
    };
  }

  static AppSession fromMap(Map<String, Object?> row) {
    return AppSession(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      token: row['token'] as String,
      deviceId: row['device_id'] as String,
      createdAt: ModelCodec.fromEpochMs(row['created_at'] as int?) ??
          DateTime.now(),
      expiresAt:
          ModelCodec.fromEpochMs(row['expires_at'] as int?) ?? DateTime.now(),
      lastActivityAt: ModelCodec.fromEpochMs(row['last_activity_at'] as int?) ??
          DateTime.now(),
      isActive: ModelCodec.intToBool(row['is_active']),
    );
  }
}
