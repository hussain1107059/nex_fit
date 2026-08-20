import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart' show Database;

import '../../../core/constants/app_constants.dart';
import '../../../core/security/uuid_generator.dart';
import '../../../core/security/value_masker.dart';
import '../../../domain/entities/security_enums.dart';
import '../../../domain/entities/sync_conflict_record.dart';
import '../../../domain/entities/sync_event.dart';
import '../../../domain/entities/sync_state.dart';
import '../../../domain/repositories/sync_conflict_repository.dart';
import '../../../domain/repositories/sync_event_repository.dart';
import '../../../domain/repositories/sync_state_repository.dart';
import '../../datasources/local/app_database.dart';
import 'remote_change_applier.dart';
import 'sync_contracts.dart';
import 'sync_log.dart';
import 'sync_table_registry.dart';

export 'sync_contracts.dart';

/// How a conflict between a local event and the remote revision is settled.
enum ConflictDecision { local, remote, manual }

/// Pure conflict resolution policy.
class ConflictResolver {
  const ConflictResolver();

  /// Decides which revision wins for [strategy]. `latestWins` keeps the newer
  /// revision, `manualMerge` flags the event for manual resolution.
  ConflictDecision resolve({
    required SyncEvent local,
    required SyncEvent remote,
    required SyncConflictStrategy strategy,
  }) {
    if (local.id == remote.id) return ConflictDecision.local;
    switch (strategy) {
      case SyncConflictStrategy.latestWins:
        return local.updatedAt.isAfter(remote.updatedAt)
            ? ConflictDecision.local
            : ConflictDecision.remote;
      case SyncConflictStrategy.manualMerge:
        return ConflictDecision.manual;
    }
  }
}

/// Result of a single sync run (push + pull).
class SyncRunResult {
  const SyncRunResult({
    this.processed = 0,
    this.succeeded = 0,
    this.failed = 0,
    this.conflicts = 0,
    this.pulled = 0,
    this.hasPulled = false,
  });

  final int processed;
  final int succeeded;
  final int failed;
  final int conflicts;

  /// Number of remote changes applied from the pull phase.
  final int pulled;

  /// True once the pull phase ran (even with zero changes).
  final bool hasPulled;

  bool get hasErrors => failed > 0 || conflicts > 0;

  SyncRunResult copyWith({
    int? processed,
    int? succeeded,
    int? failed,
    int? conflicts,
    int? pulled,
    bool? hasPulled,
  }) {
    return SyncRunResult(
      processed: processed ?? this.processed,
      succeeded: succeeded ?? this.succeeded,
      failed: failed ?? this.failed,
      conflicts: conflicts ?? this.conflicts,
      pulled: pulled ?? this.pulled,
      hasPulled: hasPulled ?? this.hasPulled,
    );
  }
}

/// Snapshot of the offline sync queue used by the UI (health card / settings).
class SyncQueueSnapshot {
  const SyncQueueSnapshot({
    this.pending = 0,
    this.completed = 0,
    this.failed = 0,
    this.lastSyncedAt,
  });

  final int pending;
  final int completed;
  final int failed;
  final DateTime? lastSyncedAt;

  bool get isClean => pending == 0 && failed == 0;
}

/// Exponential retry scheduler for the outbox (Part 17).
///
/// Backoff (seconds): 2, 5, 15, 30, 60, 120, 300 — the final value caps the
/// sequence for any further retry.
abstract final class RetryScheduler {
  static const List<int> _backoff = AppConstants.syncRetryBackoffSeconds;

  static DateTime nextRetryAt(int currentRetryCount, {DateTime? now}) {
    final int index = currentRetryCount.clamp(0, _backoff.length - 1);
    return (now ?? DateTime.now()).add(Duration(seconds: _backoff[index]));
  }
}

/// Simple per-user async mutex so two sync runs can never overlap (Part 15).
class SyncLock {
  Future<void> _tail = Future<void>.value();

  Future<T> synchronized<T>(Future<T> Function() action) {
    final Future<void> previous = _tail;
    final Completer<void> completer = Completer<void>();
    _tail = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }
}

/// The offline-first two-way sync engine.
///
/// Local mutations are recorded as [SyncEvent]s (see [track]) into the durable
/// outbox. [processQueue] pushes them to a [SyncTransport] using the outbox
/// protocol (PENDING -> PROCESSING -> SUCCESS / FAILED_RETRYABLE /
/// FAILED_PERMANENT). [pull] drains remote `sync_changes` into the local
/// database and advances the per-user cursor only after the batch commits
/// (Parts 10-12). [sync] orchestrates push then pull under a per-user lock.
class SyncEngine {
  SyncEngine({
    required this.repository,
    this.syncStateRepository,
    this.conflictRepository,
    this.database,
    this.deviceIdProvider,
    Logger? logger,
  }) : _logger = logger ?? Logger('SyncEngine');

  final SyncEventRepository repository;
  final SyncStateRepository? syncStateRepository;

  /// Durable conflict store (PROMPT 19). When present, every optimistic-lock
  /// conflict writes a [SyncConflictRecord] capturing both sides.
  final SyncConflictRepository? conflictRepository;

  /// Local database used to snapshot the conflicting local row. Optional so the
  /// engine keeps working without it (conflicts still resolve, but no local
  /// snapshot is recorded).
  final AppDatabase? database;

  /// Resolves the stable per-install device id (see `DeviceIdService`).
  final Future<String> Function()? deviceIdProvider;
  final Logger _logger;

  final Map<String, SyncLock> _locks = <String, SyncLock>{};

  SyncLock _lockFor(String userId) =>
      _locks.putIfAbsent(userId, () => SyncLock());

  /// Records a mutation. Duplicate pending events for the same entity are
  /// merged (duplicate detection) so a fast update does not flood the queue.
  ///
  /// The [SyncEvent.eventUuid] is generated exactly once here and preserved on
  /// merge, so every retry reuses the same idempotency key (Part 3). The
  /// current device id is stamped when a [deviceIdProvider] is installed.
  Future<void> track({
    required String userId,
    required String entity,
    required String entityId,
    required SyncOperation operation,
    String? payload,
    int baseVersion = 0,
  }) async {
    final DateTime now = DateTime.now();
    final SyncEvent? duplicate = await repository.findDuplicate(
      userId,
      entity,
      entityId,
      operation,
    );
    if (duplicate != null) {
      await repository.update(
        duplicate.copyWith(
          payload: payload ?? duplicate.payload,
          baseVersion: baseVersion == 0 ? duplicate.baseVersion : baseVersion,
          updatedAt: now,
          clearNextRetryAt: true,
          clearError: true,
        ),
      );
      return;
    }

    await repository.insert(
      SyncEvent(
        userId: userId,
        entity: entity,
        entityId: entityId,
        operation: operation,
        payload: payload,
        eventUuid: UuidGenerator.v4(),
        deviceId: await _deviceId(),
        baseVersion: baseVersion,
        status: SyncStatus.pending,
        conflictStrategy: SyncConflictStrategy.latestWins,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<String?> _deviceId() async {
    final Future<String> Function()? provider = deviceIdProvider;
    if (provider == null) return null;
    try {
      return await provider();
    } catch (_) {
      return null;
    }
  }

  /// Maximum number of events fetched per queue-processing page.
  static const int _queuePageSize = AppConstants.syncQueuePageSize;

  /// Reclaims PROCESSING events stuck longer than the safe timeout (Part 18).
  /// Returns the number of reclaimed events.
  Future<int> resetStuckProcessingEvents(
    String userId, {
    DateTime? now,
  }) async {
    final DateTime at = now ?? DateTime.now();
    final List<int> reclaimed = await repository.resetStuckProcessingEvents(
      userId,
      olderThan: at.subtract(AppConstants.syncStuckProcessingTimeout),
      at: at,
    );
    if (reclaimed.isNotEmpty) {
      SyncLog.info(
        _logger,
        SyncLog.start,
        'reclaimed ${reclaimed.length} stuck PROCESSING events '
        '(user=${SyncLog.maskUserId(userId)})',
      );
    }
    return reclaimed.length;
  }

  /// Pushes the outbox for [userId] to [transport]. Without a ready transport
  /// every event is acknowledged locally (offline-first).
  ///
  /// Uses the outbox protocol: mark PROCESSING before the network call, then
  /// SUCCESS, FAILED_RETRYABLE (with backoff) or FAILED_PERMANENT.
  Future<SyncRunResult> processQueue(
    String userId, {
    SyncTransport? transport,
  }) {
    final SyncLock lock = _lockFor(userId);
    return lock.synchronized(
      () => _processQueueUnlocked(userId, transport: transport),
    );
  }

  Future<SyncRunResult> _processQueueUnlocked(
    String userId, {
    SyncTransport? transport,
  }) async {
    final DateTime runAt = DateTime.now();
    await resetStuckProcessingEvents(userId, now: runAt);

    SyncRunResult result = const SyncRunResult();
    final bool online = transport != null && transport.isReady;

    // Drain the outbox by re-querying the front of the eligible set on every
    // pass instead of OFFSET pagination (PROMPT 20/21). Each event transitions
    // to PROCESSING (claimed) while being handled, and then to COMPLETED /
    // FAILED_* or a future `next_retry_at`, so every pass returns the next
    // not-yet-claimed batch. OFFSET over a shrinking set would silently skip
    // events once more than one page is pending.
    while (true) {
      final List<SyncEvent> page = await repository.getRetryableByUserId(
        userId,
        limit: _queuePageSize,
        now: runAt,
      );
      if (page.isEmpty) break;

      for (final SyncEvent event in page) {
        result = result.copyWith(processed: result.processed + 1);
        await _processOne(
          userId,
          event,
          transport: transport,
          online: online,
          runAt: runAt,
          onSucceeded: () {
            result = result.copyWith(succeeded: result.succeeded + 1);
          },
          onFailed: () {
            result = result.copyWith(failed: result.failed + 1);
          },
          onConflict: () {
            result = result.copyWith(conflicts: result.conflicts + 1);
          },
        );
      }
    }

    return result;
  }

  Future<void> _processOne(
    String userId,
    SyncEvent event, {
    required SyncTransport? transport,
    required bool online,
    required DateTime runAt,
    required void Function() onSucceeded,
    required void Function() onFailed,
    required void Function() onConflict,
  }) async {
    final int eventId = event.id!;

    if (!online) {
      if (transport == null) {
        // No transport configured at all (offline-only build): acknowledge
        // pending events locally so the queue drains and never grows against
        // a cloud that does not exist.
        await repository.markSuccess(
          eventId,
          at: runAt,
          syncedAt: runAt,
        );
        onSucceeded();
        return;
      }
      // A transport exists but is not ready yet (Supabase configured but the
      // client is still initializing, auth not loaded, or the device is
      // offline). NEVER ack as success — that would drop the mutation from
      // the cloud sync forever. Keep the event pending with a backoff so the
      // next run (periodic timer, network recovery, resume) pushes it once
      // the transport becomes ready.
      await repository.update(
        event.copyWith(
          status: SyncStatus.pending,
          lastError: 'transport_not_ready',
          nextRetryAt: RetryScheduler.nextRetryAt(
            event.retryCount,
            now: runAt,
          ),
          updatedAt: runAt,
        ),
      );
      return;
    }

    await repository.markProcessing(eventId, at: runAt);
    SyncLog.info(
      _logger,
      SyncLog.pushStart,
      'event=${SyncLog.maskEventUuid(event.eventUuid)} '
      'entity=${event.entity} op=${event.operation.name}',
    );

    try {
      final SyncPushResult pushResult = await transport!.push(event);
      if (pushResult.applied) {
        await repository.markSuccess(eventId, at: runAt, syncedAt: runAt);
        SyncLog.info(
          _logger,
          SyncLog.pushSuccess,
          'event=${SyncLog.maskEventUuid(event.eventUuid)} '
          'row_version=${pushResult.serverRowVersion}',
        );
        onSucceeded();
        return;
      }
      if (pushResult.conflict) {
        await _handleConflict(event, pushResult, runAt);
        SyncLog.warning(
          _logger,
          SyncLog.conflictDetected,
          'event=${SyncLog.maskEventUuid(event.eventUuid)} '
          'entity=${event.entity} strategy=${event.conflictStrategy.name} '
          'server_v=${pushResult.serverRowVersion}',
        );
        onConflict();
        return;
      }
      // Unsupported entity / local row missing: terminal, non-retryable.
      await repository.markPermanentFailure(
        eventId,
        lastError: pushResult.lastError ?? 'push_rejected',
        retryCount: event.retryCount + 1,
        at: runAt,
      );
      SyncLog.warning(
        _logger,
        SyncLog.pushFailure,
        'event=${SyncLog.maskEventUuid(event.eventUuid)} '
        'error=${pushResult.lastError}',
      );
      onFailed();
    } on SyncTransportException catch (error) {
      await _markTransportFailure(event, error, runAt);
      onFailed();
    } catch (error, stackTrace) {
      _logger.warning(
        '[${SyncLog.pushFailure}] event=${SyncLog.maskEventUuid(event.eventUuid)} '
        'unexpected: ${ValueMasker.maskEmailInText(error.toString())}',
        error,
        stackTrace,
      );
      await _markTransportFailure(
        event,
        SyncTransportException(
          'unexpected_${ValueMasker.maskEmailInText(error.toString())}',
        ),
        runAt,
      );
      onFailed();
    }
  }

  Future<void> _handleConflict(
    SyncEvent event,
    SyncPushResult pushResult,
    DateTime runAt,
  ) async {
    // Persist both sides so the conflicting local data is never silently
    // discarded (PROMPT 19).
    await _captureConflictRecord(event, pushResult, runAt);

    switch (event.conflictStrategy) {
      case SyncConflictStrategy.manualMerge:
        // Flag for manual resolution. A future `next_retry_at` (backoff) keeps
        // the event out of the current run's drain loop (the engine re-queries
        // the eligible set until empty, PROMPT 20) and retries it on a later
        // run until the user resolves it (PROMPT 21).
        await repository.update(
          event.copyWith(
            status: SyncStatus.pending,
            lastError: 'manual_merge_required',
            nextRetryAt: RetryScheduler.nextRetryAt(
              event.retryCount,
              now: runAt,
            ),
            updatedAt: runAt,
          ),
        );
      case SyncConflictStrategy.latestWins:
        // Default resolution is SERVER_WINS (PROMPT 19): the server revision
        // is authoritative. The pull phase runs immediately after push and
        // applies the remote row locally, overwriting the stale local edit. The
        // local change is preserved in the conflict record for recovery/review.
        await repository.markSuccess(event.id!, at: runAt, syncedAt: runAt);
    }
  }

  /// Snapshots the local and server row of a stale write into the durable
  /// conflict store. Best-effort: recording must never break the push path.
  Future<void> _captureConflictRecord(
    SyncEvent event,
    SyncPushResult pushResult,
    DateTime runAt,
  ) async {
    final SyncConflictRepository? conflictStore = conflictRepository;
    if (conflictStore == null) return;

    final SyncTableMapping? mapping =
        SyncTableRegistry.byLocalTable(event.entity);
    Map<String, Object?>? localRow;
    var localVersion = event.baseVersion;
    DateTime? localUpdatedAt;
    var recordUuid = event.entityId;
    if (mapping != null && database != null) {
      try {
        final Database db = await database!.database;
        final List<Map<String, Object?>> rows = await db.query(
          mapping.localTable,
          where: '${mapping.localKeyColumn} = ?',
          whereArgs: <Object?>[
            mapping.localKeyColumn == 'user_id'
                ? event.userId
                : event.entityId,
          ],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          localRow = rows.first;
          localVersion =
              (localRow['row_version'] as num?)?.toInt() ?? event.baseVersion;
          final Object? updated = localRow['updated_at'];
          if (updated is num) {
            localUpdatedAt =
                DateTime.fromMillisecondsSinceEpoch(updated.toInt());
          }
          final String? uuid = localRow['uuid'] as String?;
          if (uuid != null && uuid.isNotEmpty) recordUuid = uuid;
        }
      } catch (_) {
        // Snapshotting is best-effort.
      }
    }

    final bool serverWins =
        event.conflictStrategy == SyncConflictStrategy.latestWins;
    final SyncConflictRecord record = SyncConflictRecord(
      userId: event.userId,
      entity: event.entity,
      recordUuid: recordUuid,
      localData: _jsonOrNull(localRow),
      serverData: _jsonOrNull(pushResult.serverData),
      localVersion: localVersion,
      serverVersion: pushResult.serverRowVersion ?? 0,
      localUpdatedAt: localUpdatedAt,
      serverUpdatedAt: pushResult.serverUpdatedAt,
      detectedAt: runAt,
      status: serverWins
          ? ConflictResolutionStatus.serverWon
          : ConflictResolutionStatus.pending,
      strategy: event.conflictStrategy,
      resolvedAt: serverWins ? runAt : null,
    );
    try {
      await conflictStore.record(record);
    } catch (_) {
      // Never let conflict recording break the push path.
    }
  }

  static String? _jsonOrNull(Map<String, Object?>? row) {
    if (row == null || row.isEmpty) return null;
    return jsonEncode(row);
  }

  Future<void> _markTransportFailure(
    SyncEvent event,
    SyncTransportException error,
    DateTime runAt,
  ) async {
    final int retries = event.retryCount + 1;
    final int eventId = event.id!;
    final bool permanent =
        !error.retryable || retries >= AppConstants.syncEventMaxRetries;

    if (permanent) {
      await repository.markPermanentFailure(
        eventId,
        lastError: ValueMasker.maskEmailInText(error.message),
        retryCount: retries,
        at: runAt,
      );
      SyncLog.warning(
        _logger,
        SyncLog.pushFailure,
        'event=${SyncLog.maskEventUuid(event.eventUuid)} permanent '
        'error=${ValueMasker.maskEmailInText(error.message)}',
      );
      return;
    }

    final DateTime nextRetry = RetryScheduler.nextRetryAt(
      event.retryCount,
      now: runAt,
    );
    await repository.markRetryableFailure(
      eventId,
      lastError: ValueMasker.maskEmailInText(error.message),
      retryCount: retries,
      at: runAt,
      nextRetryAt: nextRetry,
    );
    SyncLog.warning(
      _logger,
      SyncLog.pushRetry,
      'event=${SyncLog.maskEventUuid(event.eventUuid)} attempt=$retries '
      'nextRetryAt=${nextRetry.toIso8601String()} '
      'error=${ValueMasker.maskEmailInText(error.message)}',
    );
  }

  /// Drains remote `sync_changes` for [userId] into the local database.
  ///
  /// Every batch is applied inside a single transaction together with its
  /// cursor advance, so a failure (e.g. an unsupported cloud table) rolls back
  /// Pulls remote changes after the stored cursor and advances the cursor per
  /// batch. Each batch applies inside one transaction together with its cursor
  /// advance, so the cursor never passes unapplied rows (Part 11). Applies
  /// changes via [RemoteChangeApplier] which bypasses the outbox (REMOTE_APPLY,
  /// Part 16).
  ///
  /// [maxBatches] bounds the number of pull batches served by one call
  /// (PROMPT 20). Defaults to `AppConstants.syncMaxPullBatches` for incremental
  /// runs so one run can never loop unbounded. Set [drainToEnd] to ignore the
  /// cap and drain the remote paginator to exhaustion — used by the initial
  /// sync so a >5,000-row dataset completes in a single run instead of stopping
  /// at the batch cap.
  Future<int> pull({
    required String userId,
    required SyncTransport transport,
    required RemoteChangeApplier applier,
    int? maxBatches,
    bool drainToEnd = false,
    DateTime? now,
    void Function(int applied, int cursor)? onBatchProgress,
  }) {
    final SyncLock lock = _lockFor(userId);
    return lock.synchronized(
      () => _pullUnlocked(
        userId: userId,
        transport: transport,
        applier: applier,
        maxBatches: maxBatches,
        drainToEnd: drainToEnd,
        now: now,
        onBatchProgress: onBatchProgress,
      ),
    );
  }

  Future<int> _pullUnlocked({
    required String userId,
    required SyncTransport transport,
    required RemoteChangeApplier applier,
    int? maxBatches,
    bool drainToEnd = false,
    DateTime? now,
    void Function(int applied, int cursor)? onBatchProgress,
    void Function(Map<String, int> appliedByTable, int cursor)?
        onAppliedByTable,
  }) async {
    final SyncStateRepository? stateRepository = syncStateRepository;
    if (stateRepository == null) {
      throw StateError('syncStateRepository is required for pull');
    }
    final DateTime runAt = now ?? DateTime.now();
    SyncState state =
        await stateRepository.getByUserId(userId) ??
        SyncState(userId: userId, updatedAt: runAt);
    int cursor = state.cursor;
    int pulled = 0;
    bool hasMore = true;
    int batches = 0;
    final Map<String, int> appliedByTable = <String, int>{};
    // A bounded default guards incremental runs; [drainToEnd] (initial sync)
    // drains the paginator fully.
    final int batchCap = maxBatches ?? AppConstants.syncMaxPullBatches;

    while (hasMore && (drainToEnd || batches < batchCap)) {
      SyncLog.info(
        _logger,
        SyncLog.pullStart,
        'user=${SyncLog.maskUserId(userId)} cursor=$cursor',
      );
      final SyncPullBatch batch = await transport.pull(
        userId: userId,
        cursor: cursor,
        limit: AppConstants.syncPullBatchSize,
      );
      if (batch.changes.isEmpty) {
        hasMore = false;
        break;
      }

      await _applyBatch(
        userId: userId,
        state: state,
        batch: batch,
        applier: applier,
        runAt: runAt,
        stateRepository: stateRepository,
      );

      pulled += batch.changes.length;
      for (final SyncChange change in batch.changes) {
        appliedByTable[change.cloudTable] =
            (appliedByTable[change.cloudTable] ?? 0) + 1;
      }
      final int previousCursor = cursor;
      cursor = batch.nextCursor;
      state = state.copyWith(cursor: cursor, updatedAt: runAt);
      hasMore = batch.hasMore;
      batches += 1;
      onBatchProgress?.call(pulled, cursor);
      onAppliedByTable?.call(
        Map<String, int>.unmodifiable(appliedByTable),
        cursor,
      );

      // Livelock guard: a paginator that claims more data but never advances
      // the keyset cursor would otherwise loop forever on an uncapped run.
      if (batch.hasMore && batch.nextCursor <= previousCursor) {
        hasMore = false;
        break;
      }
    }

    await stateRepository.upsert(
      state.copyWith(
        lastSyncAt: runAt,
        initialSyncCompleted: true,
        status: 'success',
        updatedAt: runAt,
      ),
    );
    SyncLog.info(
      _logger,
      SyncLog.pullSuccess,
      'user=${SyncLog.maskUserId(userId)} cursor=$cursor pulled=$pulled',
    );
    return pulled;
  }

  Future<void> _applyBatch({
    required String userId,
    required SyncState state,
    required SyncPullBatch batch,
    required RemoteChangeApplier applier,
    required DateTime runAt,
    required SyncStateRepository stateRepository,
  }) async {
    final sqfliteDatabase = await applier.database.database;
    await sqfliteDatabase.transaction((txn) async {
      // Apply parent rows before their children (PROMPT 12) so a child's
      // foreign-key parent is already resolvable within the same batch.
      for (final SyncChange change
          in orderChangesForApply(batch.changes)) {
        await applier.apply(txn, change);
      }
      // The cursor only advances inside the same transaction that committed
      // the applied rows (Part 11).
      await stateRepository.upsertInTransaction(
        txn,
        state.copyWith(cursor: batch.nextCursor, updatedAt: runAt),
      );
    });
  }

  /// Full two-way sync for [userId]: push the outbox, then pull remote
  /// changes. Runs under a per-user lock so concurrent runs cannot overlap.
  ///
  /// Ordering is deliberately push-then-pull so this device's newest writes
  /// land before it reads remote rows (documented in
  /// `docs/NEXFIT_TWO_WAY_SYNC_ARCHITECTURE.md`).
  Future<SyncRunResult> sync({
    required String userId,
    required SyncTransport transport,
    required RemoteChangeApplier applier,
  }) {
    final SyncLock lock = _lockFor(userId);
    return lock.synchronized(() async {
      SyncLog.info(
        _logger,
        SyncLog.start,
        'user=$userId transport=${transport.name}',
      );
      final SyncRunResult push = await _processQueueUnlocked(
        userId,
        transport: transport,
      );
      int pulled = 0;
      try {
        pulled = await _pullUnlocked(
          userId: userId,
          transport: transport,
          applier: applier,
        );
      } on SyncTransportException catch (error) {
        SyncLog.warning(
          _logger,
          SyncLog.pullFailure,
          'user=${SyncLog.maskUserId(userId)} '
          'error=${ValueMasker.maskEmailInText(error.message)}',
        );
        return push.copyWith(
          failed: push.failed + 1,
          hasPulled: false,
        );
      } on UnsupportedTableException catch (error) {
        // Cursor was rolled back; the pull cannot proceed. The user's push
        // already succeeded, so report a partial failure rather than aborting.
        SyncLog.warning(
          _logger,
          SyncLog.pullFailure,
          'user=${SyncLog.maskUserId(userId)} '
          '${ValueMasker.maskEmailInText(error.message)}',
        );
        return push.copyWith(
          failed: push.failed + 1,
          hasPulled: false,
        );
      }
      SyncLog.info(
        _logger,
        SyncLog.complete,
        'user=${SyncLog.maskUserId(userId)} pushed=${push.succeeded} '
        'pulled=$pulled',
      );
      return push.copyWith(pulled: pulled, hasPulled: true);
    });
  }

  /// Full re-sync: pushes pending local events, then resets the pull cursor
  /// and re-applies every remote change from scratch. Runs under the per-user
  /// lock so the cursor reset and re-pull are atomic — a concurrent run can
  /// never interleave a stale cursor write between the delete and the pull.
  Future<SyncRunResult> resetAndSync({
    required String userId,
    required SyncTransport transport,
    required RemoteChangeApplier applier,
    DateTime? now,
    void Function(Map<String, int> appliedByTable, int cursor)?
        onAppliedByTable,
  }) {
    final SyncLock lock = _lockFor(userId);
    return lock.synchronized(() async {
      SyncLog.info(
        _logger,
        SyncLog.start,
        'user=${SyncLog.maskUserId(userId)} transport=${transport.name} '
        'reset',
      );
      // Reset the cursor FIRST: even if the push or the pull below fails, the
      // stored cursor is gone, so the next sync run re-pulls from scratch and
      // self-heals. The push is best-effort and never blocks the re-pull.
      await syncStateRepository?.deleteForUser(userId);
      SyncRunResult push = const SyncRunResult();
      try {
        push = await _processQueueUnlocked(
          userId,
          transport: transport,
        );
      } on Exception catch (error) {
        SyncLog.warning(
          _logger,
          SyncLog.pushFailure,
          'user=${SyncLog.maskUserId(userId)} '
          'error=${ValueMasker.maskEmailInText(error.toString())}',
        );
      }
      // Permanently-failed writes will never be pushed again. Complete them
      // before the fresh pull so the version guard cannot freeze the affected
      // rows: the server snapshot below is authoritative and repairs them.
      await repository.resolvePermanentFailures(
        userId,
        at: now ?? DateTime.now(),
      );
      final int pulled = await _pullUnlocked(
        userId: userId,
        transport: transport,
        applier: applier,
        drainToEnd: true,
        now: now,
        onAppliedByTable: onAppliedByTable,
      );
      SyncLog.info(
        _logger,
        SyncLog.complete,
        'user=${SyncLog.maskUserId(userId)} reset pushed=${push.succeeded} '
        'pulled=$pulled',
      );
      return push.copyWith(pulled: pulled, hasPulled: true);
    });
  }

  /// Queue statistics plus the most recent successful sync timestamp.
  Future<SyncQueueSnapshot> snapshot(String userId) async {
    final Map<String, int> counts = await repository.countByStatus(userId);
    final DateTime? lastSyncedAt = await repository.latestSyncedAt(userId);
    final int pending = (counts[SyncStatus.pending.name] ?? 0) +
        (counts[SyncStatus.failedRetryable.name] ?? 0);
    final int failed = (counts[SyncStatus.failedPermanent.name] ?? 0) +
        (counts[SyncStatus.failed.name] ?? 0);
    return SyncQueueSnapshot(
      pending: pending,
      completed: counts[SyncStatus.completed.name] ?? 0,
      failed: failed,
      lastSyncedAt: lastSyncedAt,
    );
  }

  /// Purges completed events older than the retention window.
  Future<void> prune(String userId) {
    return repository.deleteCompletedOlderThan(
      userId,
      DateTime.now().subtract(AppConstants.syncEventRetention),
    );
  }
}
