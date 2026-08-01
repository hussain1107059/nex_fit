import 'package:equatable/equatable.dart';

import 'reminder.dart';

/// Aggregated reminder history metrics used by the statistics screen.
class ReminderStatistics extends Equatable {
  const ReminderStatistics({
    this.total = 0,
    this.completed = 0,
    this.missed = 0,
    this.skipped = 0,
    this.completionRate = 0,
    this.missedRate = 0,
    this.mostSuccessfulReminder,
    this.mostSuccessfulCompleted = 0,
  });

  final int total;
  final int completed;
  final int missed;
  final int skipped;

  /// Percentage (0-100) of fired reminders that were completed.
  final double completionRate;

  /// Percentage (0-100) of fired reminders that were missed.
  final double missedRate;

  /// The reminder with the most completed occurrences.
  final Reminder? mostSuccessfulReminder;
  final int mostSuccessfulCompleted;

  @override
  List<Object?> get props => [
        total,
        completed,
        missed,
        skipped,
        completionRate,
        missedRate,
        mostSuccessfulReminder,
        mostSuccessfulCompleted,
      ];
}
