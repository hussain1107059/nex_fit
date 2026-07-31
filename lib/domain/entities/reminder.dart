import 'package:equatable/equatable.dart';

import 'common_enums.dart';

/// A scheduled reminder for a recurring habit.
class Reminder extends Equatable {
  const Reminder({
    this.id,
    required this.userId,
    required this.title,
    this.body,
    this.reminderType = ReminderType.custom,
    required this.time,
    this.daysOfWeek = const <int>[],
    this.isEnabled = true,
    this.lastTriggeredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String userId;
  final String title;
  final String? body;
  final ReminderType reminderType;

  /// Reminder time of day as a 24h "HH:mm" string.
  final String time;

  /// Weekday list 1 (Monday) .. 7 (Sunday); empty means daily.
  final List<int> daysOfWeek;
  final bool isEnabled;
  final DateTime? lastTriggeredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Reminder copyWith({
    int? id,
    String? userId,
    String? title,
    String? body,
    ReminderType? reminderType,
    String? time,
    List<int>? daysOfWeek,
    bool? isEnabled,
    DateTime? lastTriggeredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      reminderType: reminderType ?? this.reminderType,
      time: time ?? this.time,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      isEnabled: isEnabled ?? this.isEnabled,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        body,
        reminderType,
        time,
        daysOfWeek,
        isEnabled,
        lastTriggeredAt,
        createdAt,
        updatedAt,
      ];
}
