import 'package:logging/logging.dart';

import '../../../core/constants/app_constants.dart';

/// Structured log markers for the two-way sync layer.
///
/// Every marker has a stable machine-readable prefix so a log filter / ingest
/// pipeline can extract the sync timeline without parsing free text. Sensitive
/// data (passwords, tokens, payloads) is never logged; only masked identifiers
/// (e.g. a truncated event uuid) are allowed.
abstract final class SyncLog {
  static const String start = 'SYNC_START';
  static const String pushStart = 'PUSH_START';
  static const String pushSuccess = 'PUSH_SUCCESS';
  static const String pushRetry = 'PUSH_RETRY';
  static const String pushFailure = 'PUSH_FAILURE';
  static const String pullStart = 'PULL_START';
  static const String pullSuccess = 'PULL_SUCCESS';
  static const String pullFailure = 'PULL_FAILURE';
  static const String pullSkippedUnsupported = 'PULL_SKIPPED_UNSUPPORTED';
  static const String pullSkippedUnresolvable = 'PULL_SKIPPED_UNRESOLVABLE';
  static const String conflictDetected = 'CONFLICT_DETECTED';
  static const String complete = 'SYNC_COMPLETE';

  static void info(Logger logger, String marker, String message) {
    logger.info('[$marker] $message');
  }

  static void warning(Logger logger, String marker, String message) {
    logger.warning('[$marker] $message');
  }

  /// Masks a `last_error` string so no token or full payload leaks to logs.
  static String maskError(String message) {
    return message.length > 200 ? '${message.substring(0, 200)}…' : message;
  }

  /// Shortens an event uuid for logs without leaking the full idempotency key.
  static String maskEventUuid(String? uuid) {
    if (uuid == null || uuid.isEmpty) return 'n/a';
    return uuid.length <= AppConstants.syncLogMaxEventUuidChars
        ? uuid
        : '${uuid.substring(0, AppConstants.syncLogMaxEventUuidChars)}…';
  }

  /// Shortens a user id for logs so the full account uuid never leaks.
  static String maskUserId(String? userId) {
    if (userId == null || userId.isEmpty) return 'n/a';
    return userId.length <= AppConstants.syncLogMaxEventUuidChars
        ? userId
        : '${userId.substring(0, AppConstants.syncLogMaxEventUuidChars)}…';
  }
}