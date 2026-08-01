import 'package:equatable/equatable.dart';

import 'common_enums.dart';

/// A contextual suggestion produced by the smart reminder engine, e.g.
/// "you haven't logged weight this week".
class SmartReminderSuggestion extends Equatable {
  const SmartReminderSuggestion({
    required this.type,
    required this.title,
    required this.body,
    required this.reason,
    this.relatedScreen,
  });

  final ReminderType type;
  final String title;
  final String body;
  final String reason;

  /// Route to open when the suggestion is accepted, if any.
  final String? relatedScreen;

  @override
  List<Object?> get props => [type, title, body, reason, relatedScreen];
}
