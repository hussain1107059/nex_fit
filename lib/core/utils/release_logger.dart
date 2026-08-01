import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Release-safe developer logging.
///
/// `devLog` is a no-op in release/profile builds so debug strings never ship
/// or execute in production (they are tree-shaken by the AOT compiler).
void devLog(
  Object? message, {
  Object? error,
  StackTrace? stackTrace,
}) {
  if (!kDebugMode) return;
  debugPrint(message.toString());
  if (error != null) debugPrint(error.toString());
  if (stackTrace != null) debugPrint(stackTrace.toString());
}

/// Configures the `logging` hierarchy for the current build mode.
///
/// The `logging` package defaults [Logger.root.level] to `Level.ALL` but ships
/// without a listener, so records are discarded. This helper wires a debug-only
/// listener and raises the release threshold to [Level.WARNING] so `info`
/// records are not even constructed in production.
///
/// Call once during app bootstrap (see `main.dart`).
void configureLogging() {
  Logger.root.level = kReleaseMode ? Level.WARNING : Level.INFO;
  if (kReleaseMode) return;
  Logger.root.onRecord.listen((LogRecord record) {
    final String line =
        '[${record.loggerName}] ${record.level.name}: ${record.message}';
    if (record.level >= Level.WARNING) {
      final Object? error = record.error;
      final StackTrace? stackTrace = record.stackTrace;
      debugPrint(error == null
          ? line
          : '$line\n$error\n${stackTrace ?? ''}');
    } else {
      debugPrint(line);
    }
  });
}
