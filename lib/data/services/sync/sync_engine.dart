import 'package:logging/logging.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/security/value_masker.dart';
import '../../../domain/entities/security_enums.dart';
import '../../../domain/entities/sync_event.dart';
import '../../../domain/repositories/sync_event_repository.dart';

/// Optional cloud transport for the sync engine.
///
/// Until a cloud backend exists the engine runs offline-first: every event is
/// acknowledged locally (pending -> completed) with the same lifecycle the
/// transport would drive. Plugging a real transport in later is a single
/// dependency swap.
abstract interface class SyncTransport {
  /// Pushes [event] to the remote store. Returns the server-side event (which
  /// may carry a conflicting revision) or throws on failure.
  Future<SyncEvent> push(SyncEvent event);
}

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

/// Result of a single queue processing run.
class SyncRunResult {
  const SyncRunResult({
    this.processed = 0,
    this.succeeded = 0,
    this.failed = 0,
    this.conflicts = 0,
  });

  final int processed;
  final int succeeded;
  final int failed;
  final int conflicts;

  bool get hasErrors => failed > 0 || conflicts > 0;

  SyncRunResult copyWith({
    int? processed,
    int? succeeded,
    int? failed,
    int? conflicts,
  }) {
    return SyncRunResult(
      processed: processed ?? this.processed,
      succeeded: succeeded ?? this.succeeded,
      failed: failed ?? this.failed,
      conflicts: conflicts ?? this.conflicts,
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

/// The offline-first sync engine.
///
/// Every tracked mutation produces a [SyncEvent] (see [track]). Events live in
/// the durable queue and are processed through the pending -> completed/failed
/// lifecycle with retry counting and conflict resolution, architected so a
/// future cloud transport can be attached without changing the queue contract.
class SyncEngine {
  SyncEngine({
    required this.repository,
    Logger? logger,
  }) : _logger = logger ?? Logger('SyncEngine');

  final SyncEventRepository repository;
  final Logger _logger;

  /// Records a mutation. Duplicate pending events for the same entity are
  /// merged (duplicate detection) so a fast update does not flood the queue.
  Future<void> track({
    required String userId,
    required String entity,
    required String entityId,
    required SyncOperation operation,
    String? payload,
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
          updatedAt: now,
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
        status: SyncStatus.pending,
        conflictStrategy: SyncConflictStrategy.latestWins,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Maximum number of pending events fetched per queue-processing pass.
  static const int _queuePageSize = 500;

  /// Processes the pending queue for [userId]. Without a [transport] every
  /// event is acknowledged locally (offline-first). With a transport, events
  /// are pushed and conflicts are resolved with [ConflictResolver].
  ///
  /// The queue is drained in bounded pages so a very large backlog never loads
  /// the entire pending list into memory.
  Future<SyncRunResult> processQueue(
    String userId, {
    SyncTransport? transport,
    ConflictResolver? resolver,
  }) async {
    final ConflictResolver conflictResolver = resolver ?? const ConflictResolver();
    SyncRunResult result = const SyncRunResult();

    int offset = 0;
    while (true) {
      final List<SyncEvent> page = await repository.getPendingByUserId(
        userId,
        limit: _queuePageSize,
        offset: offset,
      );
      if (page.isEmpty) break;

      // Completed events are accumulated and acknowledged in a single batched
      // update per page instead of one UPDATE round trip per event.
      final List<SyncEvent> toComplete = <SyncEvent>[];

      for (final SyncEvent event in page) {
        result = result.copyWith(processed: result.processed + 1);
        try {
          if (transport == null) {
            toComplete.add(_completed(event));
            result = result.copyWith(succeeded: result.succeeded + 1);
            continue;
          }

          final SyncEvent remote = await transport.push(event);
          final ConflictDecision decision = conflictResolver.resolve(
            local: event,
            remote: remote,
            strategy: event.conflictStrategy,
          );
          switch (decision) {
            case ConflictDecision.local:
            case ConflictDecision.remote:
              toComplete.add(_completed(event));
              result = result.copyWith(succeeded: result.succeeded + 1);
            case ConflictDecision.manual:
              await repository.update(
                event.copyWith(
                  lastError: 'manual_merge_required',
                  updatedAt: DateTime.now(),
                ),
              );
              result = result.copyWith(conflicts: result.conflicts + 1);
          }
        } catch (error, stackTrace) {
          _logger.warning(
            'Sync event ${event.id} failed: $error',
            error,
            stackTrace,
          );
          result = result.copyWith(failed: result.failed + 1);
          await _markFailed(event, error);
        }
      }

      if (toComplete.isNotEmpty) {
        await repository.updateAll(toComplete);
      }

      offset += page.length;
    }

    return result;
  }

  SyncEvent _completed(SyncEvent event) {
    return event.copyWith(
      status: SyncStatus.completed,
      syncedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      clearError: true,
    );
  }

  Future<void> _markFailed(SyncEvent event, Object error) async {
    final int retries = event.retryCount + 1;
    final bool giveUp = retries >= AppConstants.syncEventMaxRetries;
    await repository.update(
      event.copyWith(
        status: giveUp ? SyncStatus.failed : SyncStatus.pending,
        retryCount: retries,
        lastError: ValueMasker.maskText(error.toString()),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Queue statistics plus the most recent successful sync timestamp.
  Future<SyncQueueSnapshot> snapshot(String userId) async {
    final Map<String, int> counts = await repository.countByStatus(userId);
    final DateTime? lastSyncedAt = await repository.latestSyncedAt(userId);
    return SyncQueueSnapshot(
      pending: counts[SyncStatus.pending.name] ?? 0,
      completed: counts[SyncStatus.completed.name] ?? 0,
      failed: counts[SyncStatus.failed.name] ?? 0,
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
