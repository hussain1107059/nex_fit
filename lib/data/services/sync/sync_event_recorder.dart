import 'package:sqflite/sqflite.dart' show Transaction;

import '../../../core/security/uuid_generator.dart';
import '../../../domain/entities/security_enums.dart';
import '../../../domain/entities/sync_event.dart';
import '../../../domain/repositories/sync_event_repository.dart';
import 'sync_engine.dart';

/// Static facade that lets the data sources record sync events without
/// constructor plumbing.
///
/// Configured once at app bootstrap with the repository, the device-id
/// resolver and the current user. Writes are best-effort and no-op when not
/// configured or disabled - the offline sync layer must never block the core
/// database operations.
class SyncEventRecorder {
  SyncEventRecorder._();

  static SyncEventRepository? _repository;
  static Future<String> Function()? _deviceIdProvider;
  static String? _activeUserId;
  static bool _enabled = true;

  static SyncEventRepository? get repository => _repository;

  /// Whether recorded events are actually persisted.
  static bool get enabled => _enabled;

  /// Installs the repository, the device-id resolver and the current user id.
  static void configure({
    required SyncEventRepository repository,
    Future<String> Function()? deviceIdProvider,
    String? activeUserId,
    bool enabled = true,
  }) {
    _repository = repository;
    _deviceIdProvider = deviceIdProvider;
    _activeUserId = activeUserId;
    _enabled = enabled;
  }

  /// Updates the current user id without re-configuring the repository.
  static void setActiveUser(String? userId) => _activeUserId = userId;

  static void setEnabled(bool enabled) => _enabled = enabled;

  /// The currently authenticated user (or null when no session is active).
  static String? get activeUserId => _activeUserId;

  /// Whether [userId] is the authenticated user. When no user is signed in
  /// there is nothing to validate against, so the check passes (offline).
  static bool isCurrentUser(String userId) =>
      _activeUserId == null || _activeUserId == userId;

  static SyncEngine _engine() =>
      SyncEngine(repository: _repository!, deviceIdProvider: _deviceIdProvider);

  /// Records a mutation for the sync queue. Falls back to the active user when
  /// [userId] is omitted (delete operations typically only know the row id).
  static Future<void> record({
    required String entity,
    required String entityId,
    required SyncOperation operation,
    String? userId,
    String? payload,
    int baseVersion = 0,
  }) async {
    final SyncEventRepository? repository = _repository;
    if (!_enabled || repository == null) return;
    final String? uid = userId ?? _activeUserId;
    if (uid == null) return;

    try {
      await _engine().track(
        userId: uid,
        entity: entity,
        entityId: entityId,
        operation: operation,
        payload: payload,
        baseVersion: baseVersion,
      );
    } catch (_) {
      // Never let sync recording break the write path.
    }
  }

  /// Enqueues a sync event inside an existing [Transaction] so the local
  /// mutation and its outbox entry commit atomically (Part 5 of the sync
  /// foundation). The DAO migration phase moves every tracked write to this
  /// path; see `docs/NEXFIT_DAO_SYNC_MIGRATION_PLAN.md`.
  ///
  /// The event uuid is generated once here; [onEvent] receives the fully
  /// stamped event before insert so a DAO can capture the generated `uuid`
  /// when it writes the row.
  static Future<void> recordInTransaction(
    Transaction txn, {
    required String entity,
    required String entityId,
    required SyncOperation operation,
    required String userId,
    String? payload,
    int baseVersion = 0,
  }) async {
    final SyncEventRepository? repository = _repository;
    if (!_enabled || repository == null) return;

    try {
      final String deviceId = await _resolveDeviceId();
      await repository.insertInTransaction(
        txn,
        SyncEvent(
          userId: userId,
          entity: entity,
          entityId: entityId,
          operation: operation,
          payload: payload,
          eventUuid: UuidGenerator.v4(),
          deviceId: deviceId,
          baseVersion: baseVersion,
          status: SyncStatus.pending,
          conflictStrategy: SyncConflictStrategy.latestWins,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // Never let sync recording break the write path.
    }
  }

  static Future<String> _resolveDeviceId() async {
    final Future<String> Function()? provider = _deviceIdProvider;
    if (provider == null) return '';
    try {
      return await provider();
    } catch (_) {
      return '';
    }
  }
}
