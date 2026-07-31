import '../../domain/entities/common_enums.dart';
import '../../domain/entities/reminder.dart';
import 'model_codec.dart';

/// Maps [Reminder] to and from rows in the `reminder` table.
/// The [Reminder.daysOfWeek] list is persisted as a comma-separated string.
class ReminderModel {
  ReminderModel._();

  static const String table = 'reminder';

  static const String _separator = ',';

  static Map<String, Object?> toMap(Reminder reminder) {
    return <String, Object?>{
      'id': reminder.id,
      'user_id': reminder.userId,
      'title': reminder.title,
      'body': reminder.body,
      'reminder_type': reminder.reminderType.name,
      'time': reminder.time,
      'days_of_week': reminder.daysOfWeek.join(_separator),
      'is_enabled': ModelCodec.boolToInt(reminder.isEnabled),
      'last_triggered_at': ModelCodec.epochMs(reminder.lastTriggeredAt),
      'created_at': ModelCodec.epochMs(reminder.createdAt),
      'updated_at': ModelCodec.epochMs(reminder.updatedAt),
    };
  }

  static Reminder fromMap(Map<String, Object?> row) {
    final String? days = row['days_of_week'] as String?;
    return Reminder(
      id: row['id'] as int?,
      userId: row['user_id'] as String,
      title: row['title'] as String,
      body: row['body'] as String?,
      reminderType: ReminderType.fromName(row['reminder_type'] as String?),
      time: row['time'] as String,
      daysOfWeek: days == null || days.isEmpty
          ? const <int>[]
          : days
                .split(_separator)
                .map((day) => int.tryParse(day.trim()))
                .whereType<int>()
                .toList(),
      isEnabled: ModelCodec.intToBool(row['is_enabled']),
      lastTriggeredAt: ModelCodec.fromEpochMs(row['last_triggered_at'] as int?),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }
}
