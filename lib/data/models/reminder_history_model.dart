import '../../domain/entities/common_enums.dart';
import '../../domain/entities/reminder_history.dart';
import 'model_codec.dart';

/// Maps [ReminderHistory] to and from rows in the `reminder_history` table.
class ReminderHistoryModel {
  ReminderHistoryModel._();

  static const String table = 'reminder_history';

  static Map<String, Object?> toMap(ReminderHistory history) {
    return <String, Object?>{
      'id': history.id,
      'user_id': history.userId,
      'reminder_id': history.reminderId,
      'status': history.status.name,
      'scheduled_for': ModelCodec.epochMs(history.scheduledFor),
      'acted_at': ModelCodec.epochMs(history.actedAt),
      'created_at':
          ModelCodec.epochMs(history.createdAt) ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  static ReminderHistory fromMap(Map<String, Object?> row) {
    return ReminderHistory(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      reminderId: row['reminder_id'] as int?,
      status: ReminderHistoryStatus.fromName(row['status'] as String?),
      scheduledFor: ModelCodec.fromEpochMs(row['scheduled_for'] as int?) ??
          DateTime.now(),
      actedAt: ModelCodec.fromEpochMs(row['acted_at'] as int?),
      createdAt: ModelCodec.fromEpochMs(row['created_at'] as int?),
    );
  }
}
