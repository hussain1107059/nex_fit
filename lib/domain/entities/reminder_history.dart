import 'package:equatable/equatable.dart';

import 'common_enums.dart';

/// A single recorded occurrence of a reminder: completed by the user,
/// skipped via the notification action, or missed when it fired unattended.
class ReminderHistory extends Equatable {
  const ReminderHistory({
    this.id,
    required this.userId,
    this.reminderId,
    required this.status,
    required this.scheduledFor,
    this.actedAt,
    this.createdAt,
  });

  final int? id;
  final String userId;
  final int? reminderId;
  final ReminderHistoryStatus status;

  /// The exact datetime the reminder was scheduled to fire.
  final DateTime scheduledFor;

  /// When the user acted on it (completed/skipped); null for missed.
  final DateTime? actedAt;

  final DateTime? createdAt;

  ReminderHistory copyWith({
    int? id,
    String? userId,
    int? reminderId,
    ReminderHistoryStatus? status,
    DateTime? scheduledFor,
    DateTime? actedAt,
    DateTime? createdAt,
  }) {
    return ReminderHistory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      reminderId: reminderId ?? this.reminderId,
      status: status ?? this.status,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      actedAt: actedAt ?? this.actedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        reminderId,
        status,
        scheduledFor,
        actedAt,
        createdAt,
      ];
}
