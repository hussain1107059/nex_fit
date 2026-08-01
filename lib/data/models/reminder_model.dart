import 'dart:convert';

import '../../domain/entities/common_enums.dart';
import '../../domain/entities/reminder.dart';
import '../services/security/encryption_service.dart';
import 'model_codec.dart';

/// Maps [Reminder] to and from rows in the `reminder` table.
///
/// List columns ([Reminder.daysOfWeek], [Reminder.times]) are persisted as
/// comma-separated / JSON strings so they survive round-trips unchanged.
/// Free-text title/body are field-encrypted when encryption is enabled.
class ReminderModel {
  ReminderModel._();

  static const String table = 'reminder';

  static const String _separator = ',';

  static Map<String, Object?> toMap(Reminder reminder) {
    return <String, Object?>{
      'id': reminder.id,
      'user_id': reminder.userId,
      'title': FieldEncryption.encrypt(reminder.title),
      'body': FieldEncryption.encrypt(reminder.body),
      'reminder_type': reminder.reminderType.name,
      'time': reminder.time,
      'days_of_week': reminder.daysOfWeek.join(_separator),
      'schedule_type': reminder.scheduleType.name,
      'times': jsonEncode(reminder.times),
      'start_date': ModelCodec.epochMs(reminder.startDate),
      'end_date': ModelCodec.epochMs(reminder.endDate),
      'month_day': reminder.monthDay,
      'icon': reminder.icon,
      'color_value': reminder.colorValue,
      'sound_enabled': ModelCodec.boolToInt(reminder.soundEnabled),
      'vibration_enabled': ModelCodec.boolToInt(reminder.vibrationEnabled),
      'silent_mode': ModelCodec.boolToInt(reminder.silentMode),
      'show_action_buttons': ModelCodec.boolToInt(reminder.showActionButtons),
      'related_screen': reminder.relatedScreen,
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
      title: FieldEncryption.decrypt(row['title'] as String) ?? '',
      body: FieldEncryption.decrypt(row['body'] as String?),
      reminderType: ReminderType.fromName(row['reminder_type'] as String?),
      time: row['time'] as String,
      daysOfWeek: days == null || days.isEmpty
          ? const <int>[]
          : days
                .split(_separator)
                .map((day) => int.tryParse(day.trim()))
                .whereType<int>()
                .toList(),
      scheduleType: ReminderScheduleType.fromName(
        row['schedule_type'] as String?,
      ),
      times: _decodeTimes(row['times'] as String?),
      startDate: ModelCodec.fromEpochMs(row['start_date'] as int?),
      endDate: ModelCodec.fromEpochMs(row['end_date'] as int?),
      monthDay: row['month_day'] as int?,
      icon: row['icon'] as String?,
      colorValue: row['color_value'] as int?,
      soundEnabled: ModelCodec.intToBool(row['sound_enabled']),
      vibrationEnabled: ModelCodec.intToBool(row['vibration_enabled']),
      silentMode: ModelCodec.intToBool(row['silent_mode']),
      showActionButtons: ModelCodec.intToBool(row['show_action_buttons']),
      relatedScreen: row['related_screen'] as String?,
      isEnabled: ModelCodec.intToBool(row['is_enabled']),
      lastTriggeredAt: ModelCodec.fromEpochMs(row['last_triggered_at'] as int?),
      createdAt:
          ModelCodec.fromEpochMs(row['created_at'] as int?) ?? DateTime.now(),
      updatedAt:
          ModelCodec.fromEpochMs(row['updated_at'] as int?) ?? DateTime.now(),
    );
  }

  static List<String> _decodeTimes(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const <String>[];
    try {
      final List<dynamic> decoded = jsonDecode(encoded) as List<dynamic>;
      return decoded.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }
}
