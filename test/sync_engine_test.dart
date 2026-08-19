import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/core/constants/app_constants.dart';
import 'package:nexfit/data/services/sync/sync_engine.dart';
import 'package:nexfit/domain/entities/security_enums.dart';
import 'package:nexfit/domain/entities/sync_event.dart';
import 'package:nexfit/domain/repositories/sync_event_repository.dart';

/// In-memory [SyncEventRepository] mirroring the SQFlite table semantics used
/// by the production data source.
class _MemorySyncEventRepository implements SyncEventRepository {
  final List<SyncEvent> events = <SyncEvent>[];
  int _nextId = 1;

  @override
  Future<int> insert(SyncEvent event) async {
    final SyncEvent copy = event.copyWith(id: _nextId++);
    events.add(copy);
    return copy.id!;
  }

  @override
  Future<void> insertInTransaction(
    Object txn,
    SyncEvent event,
  ) async {
    await insert(event);
  }

  @override
  Future<void> update(SyncEvent event) async {
    final int index = events.indexWhere((SyncEvent e) => e.id == event.id);
    if (index >= 0) events[index] = event;
  }

  @override
  Future<void> updateAll(List<SyncEvent> updated) async {
    for (final SyncEvent event in updated) {
      final int index = events.indexWhere((SyncEvent e) => e.id == event.id);
      if (index >= 0) events[index] = event;
    }
  }

  @override
  Future<List<SyncEvent>> getPendingByUserId(
    String userId, {
    int? limit,
    int? offset,
  }) async {
    return getRetryableByUserId(userId, limit: limit, offset: offset);
  }

  @override
  Future<List<SyncEvent>> getNonCompletedByUserId(
    String userId, {
    int limit = 100,
  }) async {
    return events
        .where(
          (SyncEvent e) =>
              e.userId == userId &&
              e.status != SyncStatus.completed,
        )
        .take(limit)
        .toList();
  }

  @override
  Future<void> requeueAllByUserId(String userId, {required DateTime at}) async {
    for (int i = 0; i < events.length; i++) {
      final SyncEvent e = events[i];
      if (e.userId == userId && e.status != SyncStatus.completed) {
        events[i] = e.copyWith(
          status: SyncStatus.pending,
          retryCount: 0,
          nextRetryAt: null,
          clearNextRetryAt: true,
          lastError: 'requeued_manually',
        );
      }
    }
  }

  @override
  Future<List<SyncEvent>> getRetryableByUserId(
    String userId, {
    int? limit,
    int? offset,
    DateTime? now,
  }) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    List<SyncEvent> pending = events
        .where(
          (SyncEvent e) =>
              e.userId == userId &&
              (e.status == SyncStatus.pending ||
                  e.status == SyncStatus.failedRetryable) &&
              (e.nextRetryAt == null || !e.nextRetryAt!.isAfter(effectiveNow)),
        )
        .toList()
      ..sort((SyncEvent a, SyncEvent b) => a.createdAt.compareTo(b.createdAt));
    if (offset != null && offset > 0) {
      if (offset >= pending.length) return <SyncEvent>[];
      pending = pending.sublist(offset);
    }
    if (limit != null && pending.length > limit) {
      pending = pending.sublist(0, limit);
    }
    return pending;
  }

  @override
  Future<SyncEvent?> findDuplicate(
    String userId,
    String entity,
    String entityId,
    SyncOperation operation,
  ) async {
    final List<SyncEvent> matches = events
        .where(
          (SyncEvent e) =>
              e.userId == userId &&
              e.entity == entity &&
              e.entityId == entityId &&
              e.operation == operation &&
              e.status == SyncStatus.pending,
        )
        .toList();
    return matches.isEmpty ? null : matches.last;
  }

  @override
  Future<Map<String, int>> countByStatus(String userId) async {
    final Map<String, int> counts = <String, int>{
      for (final SyncStatus status in SyncStatus.values) status.name: 0,
    };
    for (final SyncEvent e in events.where((SyncEvent e) => e.userId == userId)) {
      counts[e.status.name] = (counts[e.status.name] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<DateTime?> latestSyncedAt(String userId) async {
    final List<DateTime> synced = events
        .where(
          (SyncEvent e) => e.userId == userId && e.syncedAt != null,
        )
        .map((SyncEvent e) => e.syncedAt!)
        .toList()
      ..sort();
    return synced.isEmpty ? null : synced.last;
  }

  @override
  Future<void> deleteCompletedOlderThan(String userId, DateTime threshold) async {
    events.removeWhere(
      (SyncEvent e) =>
          e.userId == userId &&
          e.status == SyncStatus.completed &&
          (e.syncedAt?.isBefore(threshold) ?? false),
    );
  }

  @override
  Future<void> deleteCompletedOlderThanAll(DateTime threshold) async {
    events.removeWhere(
      (SyncEvent e) =>
          e.status == SyncStatus.completed &&
          (e.syncedAt?.isBefore(threshold) ?? false),
    );
  }

  @override
  Future<void> markProcessing(int id, {required DateTime at}) async {
    await _set(
      id,
      <String, Object?>{
        'status': SyncStatus.processing.name,
        'updated_at': at,
      },
    );
  }

  @override
  Future<void> markSuccess(
    int id, {
    required DateTime at,
    required DateTime syncedAt,
  }) async {
    await _set(
      id,
      <String, Object?>{
        'status': SyncStatus.completed.name,
        'updated_at': at,
        'synced_at': syncedAt,
      },
    );
  }

  @override
  Future<void> markRetryableFailure(
    int id, {
    required String lastError,
    required int retryCount,
    required DateTime at,
    required DateTime nextRetryAt,
  }) async {
    await _set(
      id,
      <String, Object?>{
        'status': SyncStatus.failedRetryable.name,
        'retry_count': retryCount,
        'last_error': lastError,
        'next_retry_at': nextRetryAt,
        'updated_at': at,
      },
    );
  }

  @override
  Future<void> markPermanentFailure(
    int id, {
    required String lastError,
    required int retryCount,
    required DateTime at,
  }) async {
    await _set(
      id,
      <String, Object?>{
        'status': SyncStatus.failedPermanent.name,
        'retry_count': retryCount,
        'last_error': lastError,
        'updated_at': at,
      },
    );
  }

  Future<void> _set(int id, Map<String, Object?> fields) async {
    final int index = events.indexWhere((SyncEvent e) => e.id == id);
    if (index < 0) return;
    final SyncEvent current = events[index];
    final SyncEvent next = current.copyWith(
      status: SyncStatus.fromName(fields['status'] as String?),
      updatedAt: fields['updated_at'] as DateTime? ?? current.updatedAt,
      syncedAt: fields['synced_at'] as DateTime? ?? current.syncedAt,
      retryCount: fields['retry_count'] as int? ?? current.retryCount,
      lastError: fields['last_error'] as String? ?? current.lastError,
      nextRetryAt: fields['next_retry_at'] as DateTime?,
    );
    events[index] = next;
  }

  @override
  Future<List<int>> resetStuckProcessingEvents(
    String userId, {
    required DateTime olderThan,
    required DateTime at,
  }) async {
    final List<int> stuck = <int>[];
    for (int i = 0; i < events.length; i++) {
      final SyncEvent e = events[i];
      if (e.userId == userId &&
          e.status == SyncStatus.processing &&
          (e.updatedAt.isBefore(olderThan))) {
        stuck.add(e.id!);
        events[i] = e.copyWith(
          status: SyncStatus.pending,
          updatedAt: at,
          lastError: 'reclaimed_stuck_processing',
          nextRetryAt: null,
        );
      }
    }
    return stuck;
  }

  @override
  Future<int> getPendingCount(String userId) async {
    return (await getRetryableByUserId(userId)).length;
  }

  @override
  Future<int> getFailedCount(String userId) async {
    return events
        .where(
          (SyncEvent e) =>
              e.userId == userId &&
              (e.status == SyncStatus.failedPermanent ||
                  e.status == SyncStatus.failed),
        )
        .length;
  }
}

/// Transport that returns a fixed push result and no pull data.
class _EchoTransport implements SyncTransport {
  _EchoTransport({
    this.applied = true,
    this.conflict = false,
    this.throwError = false,
  });

  final bool applied;
  final bool conflict;
  final bool throwError;

  @override
  String get name => 'echo';

  @override
  bool get isReady => true;

  @override
  Future<SyncPushResult> push(SyncEvent event) {
    if (throwError) {
      throw StateError('transport offline');
    }
    return Future.value(
      SyncPushResult(applied: applied, conflict: conflict),
    );
  }

  @override
  Future<SyncPullBatch> pull({
    required String userId,
    required int cursor,
    int limit = 100,
  }) async {
    return const SyncPullBatch(changes: <SyncChange>[], nextCursor: 0, hasMore: false);
  }
}

SyncEvent _event(
  String entityId, {
  SyncConflictStrategy strategy = SyncConflictStrategy.latestWins,
  DateTime? updatedAt,
}) {
  final DateTime now = DateTime.now();
  return SyncEvent(
    userId: 'user-1',
    entity: 'weight',
    entityId: entityId,
    operation: SyncOperation.update,
    payload: '{"kg":80}',
    conflictStrategy: strategy,
    createdAt: now,
    updatedAt: updatedAt ?? now,
  );
}

void main() {
  late _MemorySyncEventRepository repository;
  late SyncEngine engine;

  setUp(() {
    repository = _MemorySyncEventRepository();
    engine = SyncEngine(repository: repository);
  });

test('track inserts a pending event with an event uuid', () async {
    await engine.track(
      userId: 'user-1',
      entity: 'weight',
      entityId: 'w1',
      operation: SyncOperation.update,
    );

    expect(repository.events, hasLength(1));
    expect(repository.events.single.status, SyncStatus.pending);
    expect(repository.events.single.eventUuid, isNotNull);
  });

  test('duplicate pending events are merged instead of duplicated', () async {
    await engine.track(
      userId: 'user-1',
      entity: 'weight',
      entityId: 'w1',
      operation: SyncOperation.update,
      payload: '{"kg":80}',
    );
    final String firstUuid = repository.events.single.eventUuid!;
    await engine.track(
      userId: 'user-1',
      entity: 'weight',
      entityId: 'w1',
      operation: SyncOperation.update,
      payload: '{"kg":81}',
    );

    expect(repository.events, hasLength(1));
    expect(repository.events.single.payload, '{"kg":81}');
    // The idempotency key survives the merge (Part 3).
    expect(repository.events.single.eventUuid, firstUuid);
  });

  test('processQueue acknowledges every event offline', () async {
    await engine.track(
      userId: 'user-1',
      entity: 'weight',
      entityId: 'w1',
      operation: SyncOperation.update,
    );
    await engine.track(
      userId: 'user-1',
      entity: 'reminder',
      entityId: 'r1',
      operation: SyncOperation.delete,
    );

    final SyncRunResult result = await engine.processQueue('user-1');

    expect(result.processed, 2);
    expect(result.succeeded, 2);
    expect(result.failed, 0);
    expect(
      repository.events.every(
        (SyncEvent e) => e.status == SyncStatus.completed,
      ),
      isTrue,
    );
    expect(
      repository.events.every((SyncEvent e) => e.syncedAt != null),
      isTrue,
    );
  });

test('marks an event permanently failed after the retry budget is exhausted',
      () async {
    await engine.track(
      userId: 'user-1',
      entity: 'weight',
      entityId: 'w1',
      operation: SyncOperation.update,
    );

    final SyncTransport offline = _EchoTransport(throwError: true);
    for (int attempt = 1; attempt <= AppConstants.syncEventMaxRetries; attempt++) {
      await engine.processQueue('user-1', transport: offline);
      // Simulate the backoff window elapsing so the retryable event is due.
      final SyncEvent e = repository.events.single;
      if (e.status == SyncStatus.failedRetryable) {
        await repository.update(
          e.copyWith(
            nextRetryAt: DateTime.now().subtract(const Duration(seconds: 1)),
          ),
        );
      }
    }

    final SyncEvent event = repository.events.single;
    expect(event.status, SyncStatus.failedPermanent);
    expect(event.retryCount, AppConstants.syncEventMaxRetries);
    expect(event.lastError, isNotNull);
  });

  test('retryable failures schedule a backoff and stay eligible', () async {
    await engine.track(
      userId: 'user-1',
      entity: 'weight',
      entityId: 'w1',
      operation: SyncOperation.update,
    );

    final SyncTransport offline = _EchoTransport(throwError: true);
    await engine.processQueue('user-1', transport: offline);

    final SyncEvent event = repository.events.single;
    expect(event.status, SyncStatus.failedRetryable);
    expect(event.retryCount, 1);
    expect(event.nextRetryAt, isNotNull);
    // An immediate re-run must NOT process the event again (backoff gate).
    final SyncRunResult second = await engine.processQueue(
      'user-1',
      transport: offline,
    );
    expect(second.processed, 0);
  });

  test('latestWins resolves conflicts and completes the event', () async {
    await engine.track(
      userId: 'user-1',
      entity: 'weight',
      entityId: 'w1',
      operation: SyncOperation.update,
    );

    final SyncRunResult result = await engine.processQueue(
      'user-1',
      transport: _EchoTransport(applied: false, conflict: true),
    );

    expect(result.failed, 0);
    expect(result.succeeded, 0);
    expect(result.conflicts, 1);
    expect(repository.events.single.status, SyncStatus.completed);
  });

  test('manualMerge flags a conflict and keeps the event pending', () async {
    final SyncEvent conflict = _event(
      'w1',
      strategy: SyncConflictStrategy.manualMerge,
    );
    await repository.insert(conflict);

    final SyncRunResult result = await engine.processQueue(
      'user-1',
      transport: _EchoTransport(applied: false, conflict: true),
    );

    expect(result.conflicts, 1);
    expect(result.succeeded, 0);
    expect(repository.events.single.lastError, 'manual_merge_required');
    expect(repository.events.single.status, SyncStatus.pending);
  });

  test('stuck PROCESSING events are reclaimed on sync start', () async {
    await engine.track(
      userId: 'user-1',
      entity: 'weight',
      entityId: 'w1',
      operation: SyncOperation.update,
    );
    final SyncEvent event = repository.events.single;
    await repository.markProcessing(
      event.id!,
      at: DateTime.now().subtract(const Duration(minutes: 10)),
    );

    await engine.resetStuckProcessingEvents('user-1');

    final SyncEvent reclaimed = repository.events.single;
    expect(reclaimed.status, SyncStatus.pending);
    expect(reclaimed.lastError, 'reclaimed_stuck_processing');
  });

  test('snapshot reports queue statistics', () async {
    await engine.track(
      userId: 'user-1',
      entity: 'weight',
      entityId: 'w1',
      operation: SyncOperation.update,
    );
    await engine.processQueue('user-1');

    final SyncQueueSnapshot snapshot = await engine.snapshot('user-1');

    expect(snapshot.completed, 1);
    expect(snapshot.pending, 0);
    expect(snapshot.failed, 0);
    expect(snapshot.lastSyncedAt, isNotNull);
    expect(snapshot.isClean, isTrue);
  });
}

