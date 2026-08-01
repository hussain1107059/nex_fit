import 'package:equatable/equatable.dart';

import 'security_enums.dart';

/// A structured error record persisted in the `error_logs` table.
///
/// Messages and context are masked before being stored so sensitive values
/// (emails, names, notes) never leak into the log.
class ErrorLog extends Equatable {
  const ErrorLog({
    this.id,
    this.userId,
    required this.category,
    required this.message,
    this.stackTrace,
    this.context,
    required this.createdAt,
  });

  final int? id;
  final String? userId;
  final ErrorCategory category;
  final String message;
  final String? stackTrace;
  final String? context;
  final DateTime createdAt;

  @override
  List<Object?> get props =>
      [id, userId, category, message, stackTrace, context, createdAt];
}
