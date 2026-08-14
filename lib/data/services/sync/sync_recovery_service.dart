import 'package:logging/logging.dart';

import '../../../domain/entities/sync_state.dart';
import '../../../domain/repositories/sync_state_repository.dart';
import 'remote_change_applier.dart';
import 'sync_engine.dart';
import 'sync_log.dart';

/// Outcome of a startup recovery pass (PROMPT 21).
class SyncRecoveryResult {
  const SyncRecoveryResult({
    this.reclaimedStuck = 0,
    this.syncStateValid = true,
    this.resumed = 0,
    this.pulled = 0,
    this.failed = 0,
  });

  /// PROCESSING events reclaimed after an abrupt shutdown.
  final int reclaimedStuck;

  /// Whether the durable sync state passed the cursor sanity checks.
  final bool syncStateValid;

  /// Outbox events delivered (or acknowledged locally) by the resumed run.
  final int resumed;

  /// Remote changes applied by the resumed run.
  final int pulled;

  /// Failures observed by the resumed run (retryable events stay queued).
  final int failed;

  /// A healthy recovery ran on a valid sync state without failures (retryable
  /// events stay queued for a later run; they are not a health problem).
  bool get healthy => syncStateValid && failed == 0;
}

/// Sanity checks for the durable per-user sync state.
///
/// The cursor only advances inside the same transaction that applies a batch
/// (Part 11), so a stored state is expected to be internally consistent. These
/// checks are defensive: they flag states that would make a resume unsafe so
/// the caller can re-run the initial sync instead of skipping rows.
abstract final class SyncStateValidator {
  /// A healthy state is a non-negative cursor; an "initial sync completed"
  /// state must also carry a last-sync timestamp. `null` (nothing stored yet)
  /// is valid — it simply initializes on the first run.
  static bool validate(SyncState? state) {
    if (state == null) return true;
    if (state.cursor < 0) return false;
    if (state.initialSyncCompleted && state.lastSyncAt == null) return false;
    return true;
  }
}

/// Startup failure-recovery orchestrator (PROMPT 21).
///
/// Runs the recovery sequence after an abrupt exit (app killed, crash, lost
/// network mid-sync):
///
/// 1. **Recover stuck events** — reclaim PROCESSING outbox events that were
///    mid-flight when the app died.
/// 2. **Validate sync state** — sanity-check the stored cursor so a resume
///    never skips or double-applies remote rows.
/// 3. **Resume pending sync** — retry safe events: PENDING plus FAILED_RETRYABLE
///    events whose backoff window has elapsed (auth-expiry events are kept, not
///    dropped, until the session recovers).
/// 4. **Retry safe events against the cloud** — when a transport is ready,
///    drain remote changes after the stored cursor as well.
///
/// The service is deliberately small and pure orchestration: all persistence
/// and retry policy lives in [SyncEngine] and its repositories.
class SyncRecoveryService {
  SyncRecoveryService({
    required this.engine,
    this.syncStateRepository,
    Logger? logger,
  }) : _logger = logger ?? Logger('SyncRecoveryService');

  final SyncEngine engine;
  final SyncStateRepository? syncStateRepository;
  final Logger _logger;

  /// Runs the startup recovery sequence for [userId].
  ///
  /// Pass a ready [transport] (and its [applier]) to also pull remote changes;
  /// otherwise only the outbox is resumed (offline-first).
  Future<SyncRecoveryResult> recoverOnStartup({
    required String userId,
    SyncTransport? transport,
    RemoteChangeApplier? applier,
    DateTime? now,
  }) async {
    final DateTime at = now ?? DateTime.now();

    final int reclaimed = await engine.resetStuckProcessingEvents(
      userId,
      now: at,
    );
    final SyncState? state = await syncStateRepository?.getByUserId(userId);
    final bool stateValid = SyncStateValidator.validate(state);

    final bool canPull =
        transport != null && transport.isReady && applier != null;
    final SyncRunResult run = canPull
        ? await engine.sync(
            userId: userId,
            transport: transport,
            applier: applier,
          )
        : await engine.processQueue(userId, transport: transport);

    SyncLog.info(
      _logger,
      SyncLog.start,
      'user=$userId reclaimed=$reclaimed stateValid=$stateValid '
      'resumed=${run.succeeded} pulled=${run.pulled} failed=${run.failed}',
    );
    return SyncRecoveryResult(
      reclaimedStuck: reclaimed,
      syncStateValid: stateValid,
      resumed: run.succeeded,
      pulled: run.pulled,
      failed: run.failed,
    );
  }
}