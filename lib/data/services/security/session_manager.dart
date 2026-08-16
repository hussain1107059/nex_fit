import 'dart:math';

import 'package:logging/logging.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/app_session.dart';
import '../../../domain/entities/security_enums.dart';
import '../../../domain/repositories/session_repository.dart';
import '../storage/secure_storage_service.dart';
import '../sync/sync_log.dart';
import 'device_id_service.dart';

/// Secure session lifecycle: token issuance, expiry, activity tracking and
/// device-level re-login detection.
///
/// A session is created when a user signs in and is validated on cold start
/// and on resume. When the session is expired or was started on a different
/// device the previous session is deactivated (secure logout) and the user
/// must authenticate again.
class SessionManager {
  SessionManager({
    required this.repository,
    required this.storage,
    DeviceIdService? deviceIdService,
    Logger? logger,
  }) : _deviceIdService =
           deviceIdService ?? DeviceIdService(storage: storage),
       _logger = logger ?? Logger('SessionManager');

  final SessionRepository repository;
  final SecureStorageService storage;
  final DeviceIdService _deviceIdService;
  final Logger _logger;

  static const int _tokenBytes = 24;

  /// Stable per-install device id used for multi-device detection. Delegates
  /// to [DeviceIdService] so the outbox and the session share one identity.
  Future<String> getOrCreateDeviceId() => _deviceIdService.getOrCreate();

  String _generateToken() {
    final Random random = Random.secure();
    return List<String>.generate(
      _tokenBytes * 2,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  /// Starts a fresh active session for [userId], invalidating any previous
  /// session in the process.
  Future<AppSession> startSession(
    String userId, {
    Duration timeout = const Duration(minutes: 30),
  }) async {
    await repository.deactivateByUserId(userId);
    final DateTime now = DateTime.now();
    final AppSession session = AppSession(
      userId: userId,
      token: _generateToken(),
      deviceId: await getOrCreateDeviceId(),
      createdAt: now,
      expiresAt: now.add(timeout),
      lastActivityAt: now,
      isActive: true,
    );
    await repository.insert(session);
    return session;
  }

  /// Refreshes the session's activity timestamp and slides the expiry window.
  Future<void> touch(
    String userId, {
    Duration timeout = const Duration(minutes: 30),
  }) async {
    final AppSession? session = await repository.getActiveByUserId(userId);
    if (session == null) return;
    final DateTime now = DateTime.now();
    await repository.update(
      session.copyWith(
        lastActivityAt: now,
        expiresAt: now.add(timeout),
      ),
    );
  }

  /// Validates the current session. Invalidation is destructive: the session
  /// is deactivated so a subsequent call reports [SessionStatus.none].
  Future<SessionStatus> validate(
    String userId, {
    Duration timeout = const Duration(minutes: 30),
  }) async {
    final AppSession? session = await repository.getActiveByUserId(userId);
    if (session == null) return SessionStatus.none;

    final DateTime now = DateTime.now();
    final String deviceId = await getOrCreateDeviceId();

    if (session.deviceId != deviceId) {
      _logger.warning(
        'Session device mismatch for ${SyncLog.maskUserId(userId)}; '
        'deactivating for secure logout',
      );
      await repository.deactivateByUserId(userId);
      return SessionStatus.deviceChanged;
    }

    final Duration idle = now.difference(session.lastActivityAt);
    if (now.isAfter(session.expiresAt) || idle > timeout) {
      await repository.deactivateByUserId(userId);
      return SessionStatus.expired;
    }

    return SessionStatus.valid;
  }

  /// Ends the session for [userId] (secure logout). Never throws.
  Future<void> endSession(String userId) async {
    try {
      await repository.deactivateByUserId(userId);
    } catch (error, stackTrace) {
      _logger.warning('Failed to end session: $error\n$stackTrace');
    }
  }

  /// Cleans up inactive session records older than the retention window.
  Future<void> prune() async {
    try {
      await repository.deleteInactiveOlderThan(
        DateTime.now().subtract(AppConstants.sessionRetention),
      );
    } catch (error, stackTrace) {
      _logger.warning('Failed to prune sessions: $error\n$stackTrace');
    }
  }
}
