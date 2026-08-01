import '../../domain/entities/error_log.dart';
import '../../domain/entities/security_enums.dart';
import 'model_codec.dart';

/// Maps [ErrorLog] to and from rows in the `error_logs` table.
class ErrorLogModel {
  ErrorLogModel._();

  static const String table = 'error_logs';

  static Map<String, Object?> toMap(ErrorLog log) {
    return <String, Object?>{
      'id': log.id,
      'user_id': log.userId,
      'category': log.category.name,
      'message': log.message,
      'stack_trace': log.stackTrace,
      'context': log.context,
      'created_at': ModelCodec.epochMs(log.createdAt),
    };
  }

  static ErrorLog fromMap(Map<String, Object?> row) {
    return ErrorLog(
      id: row['id'] as int?,
      userId: row['user_id'] as String?,
      category: ErrorCategory.fromName(row['category'] as String?),
      message: row['message'] as String,
      stackTrace: row['stack_trace'] as String?,
      context: row['context'] as String?,
      createdAt: ModelCodec.fromEpochMs(row['created_at'] as int?) ??
          DateTime.now(),
    );
  }
}
