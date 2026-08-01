import '../../../domain/entities/security_enums.dart';
import '../../../domain/repositories/sync_event_repository.dart';
import 'sync_engine.dart';

/// Static facade that lets the data sources record sync events without
/// constructor plumbing.
///
/// Configured once at app bootstrap with the repository and the current user.
/// Writes are best-effort and no-op when not configured or disabled - the
/// offline sync layer must never block the core database operations.
class SyncEventRecorder {
  SyncEventRecorder._();

  static SyncEventRepository? _repository;
  static String? _activeUserId;
  static bool _enabled = true;

  static SyncEventRepository? get repository => _repository;

  /// Whether recorded events are actually persisted.
  static bool get enabled => _enabled;

  /// Installs the repository and the current user id resolver.
  static void configure({
    required SyncEventRepository repository,
    String? activeUserId,
    bool enabled = true,
  }) {
    _repository = repository;
    _activeUserId = activeUserId;
    _enabled = enabled;
  }

  /// Updates the current user id without re-configuring the repository.
  static void setActiveUser(String? userId) => _activeUserId = userId;

  static void setEnabled(bool enabled) => _enabled = enabled;

  /// Records a mutation for the sync queue. Falls back to the active user when
  /// [userId] is omitted (delete operations typically only know the row id).
  static Future<void> record({
    required String entity,
    required String entityId,
    required SyncOperation operation,
    String? userId,
    String? payload,
  }) async {
    final SyncEventRepository? repository = _repository;
    if (!_enabled || repository == null) return;
    final String? uid = userId ?? _activeUserId;
    if (uid == null) return;

    try {
      final SyncEngine engine = SyncEngine(repository: repository);
      await engine.track(
        userId: uid,
        entity: entity,
        entityId: entityId,
        operation: operation,
        payload: payload,
      );
    } catch (_) {
      // Never let sync recording break the write path.
    }
  }
}
