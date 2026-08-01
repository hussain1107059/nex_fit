import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/security/value_masker.dart';
import '../../../domain/entities/error_log.dart';
import '../../../domain/entities/security_enums.dart';
import '../../../domain/repositories/error_log_repository.dart';

/// Records structured, privacy-safe errors into the local `error_logs` table
/// and installs the global Flutter error handlers.
///
/// Every message and context string is masked before persistence so emails,
/// names and notes never leak into the log. All writes are best-effort: a
/// failing log write must never crash the app.
class AppErrorLogger {
  AppErrorLogger({
    required this.repository,
    Logger? logger,
  }) : _logger = logger ?? Logger('AppErrorLogger');

  final ErrorLogRepository repository;
  final Logger _logger;

  /// The single global instance wired into the Flutter error handlers.
  static AppErrorLogger? global;

  /// Optional resolver for the current signed-in user id.
  String? Function()? userIdProvider;

  /// Installs [AppErrorLogger.global] into the framework-level error
  /// handlers so unhandled exceptions are captured offline.
  void installGlobalHandlers() {
    global = this;
    FlutterError.onError = (FlutterErrorDetails details) {
      logError(
        details.exception,
        details.stack,
        category: ErrorCategory.ui,
        context: 'flutter_error',
      );
      _logger.severe(
        'Unhandled Flutter error: ${details.exception}',
        details.exception,
        details.stack,
      );
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logError(error, stack, category: ErrorCategory.ui, context: 'platform');
      return true;
    };
  }

  String? _currentUserId() {
    try {
      return userIdProvider?.call();
    } catch (_) {
      return null;
    }
  }

  Future<void> log({
    String? userId,
    ErrorCategory category = ErrorCategory.ui,
    required String message,
    String? stackTrace,
    String? context,
  }) async {
    try {
      await repository.insert(
        ErrorLog(
          userId: userId ?? _currentUserId(),
          category: category,
          message: ValueMasker.maskText(message),
          stackTrace: stackTrace == null ? null : ValueMasker.maskText(stackTrace),
          context: context == null ? null : ValueMasker.maskText(context),
          createdAt: DateTime.now(),
        ),
      );
    } catch (error, stackTrace) {
      _logger.warning('Failed to persist error log: $error\n$stackTrace');
    }
  }

  Future<void> logError(
    Object error,
    StackTrace? stackTrace, {
    ErrorCategory category = ErrorCategory.ui,
    String? context,
  }) {
    return log(
      category: category,
      message: error.toString(),
      stackTrace: stackTrace?.toString(),
      context: context,
    );
  }

  Future<List<ErrorLog>> recent({int limit = 50}) =>
      repository.getRecent(limit: limit);

  Future<int> count() => repository.count();

  /// Purges logs older than the configured retention window.
  Future<void> clearOldLogs() {
    return repository.deleteOlderThan(
      DateTime.now().subtract(AppConstants.errorLogRetention),
    );
  }
}
