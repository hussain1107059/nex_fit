import '../entities/smart_reminder_suggestion.dart';

/// Contract for the contextual "smart reminder" engine that inspects the
/// user's real progress and suggests relevant reminders.
abstract interface class SmartReminderRepository {
  /// Returns zero or more suggestions based on today's workout completion,
  /// water goal progress and weight log recency.
  Future<List<SmartReminderSuggestion>> getSuggestions(String userId);
}
