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
    List<SyncEvent> pending = events
        .where(
          (SyncEvent e) =>
              e.userId == userId && e.status == SyncStatus.pending,
        )
        .toList();
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
}

/// Transport that returns a fixed remote revision.
class _EchoTransport implements SyncTransport {
  _EchoTransport({this.remoteUpdatedAt, this.throwError = false});

  final DateTime? remoteUpdatedAt;
  final bool throwError;

  @override
  Future<SyncEvent> push(SyncEvent event) {
    if (throwError) {
      throw StateError('transport offline');
    }
    return Future.value(
      event.copyWith(
        updatedAt: remoteUpdatedAt ?? event.updatedAt,
        id: event.id == null ? 999 : event.id! + 1000,
      ),
    );
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

  test('track inserts a pending event', () async {
    await engine.track(
      userId: 'user-1',
      entity: 'weight',
      entityId: 'w1',
      operation: SyncOperation.update,
    );

    expect(repository.events, hasLength(1));
    expect(repository.events.single.status, SyncStatus.pending);
  });

  test('duplicate pending events are merged instead of duplicated', () async {
    await engine.track(
      userId: 'user-1',
      entity: 'weight',
      entityId: 'w1',
      operation: SyncOperation.update,
      payload: '{"kg":80}',
    );
    await engine.track(
      userId: 'user-1',
      entity: 'weight',
      entityId: 'w1',
      operation: SyncOperation.update,
      payload: '{"kg":81}',
    );

    expect(repository.events, hasLength(1));
    expect(repository.events.single.payload, '{"kg":81}');
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

  test('marks an event failed after the retry budget is exhausted', () async {
    await engine.track(
      userId: 'user-1',
      entity: 'weight',
      entityId: 'w1',
      operation: SyncOperation.update,
    );

    final SyncTransport offline = _EchoTransport(throwError: true);
    for (int attempt = 1; attempt <= AppConstants.syncEventMaxRetries; attempt++) {
      await engine.processQueue('user-1', transport: offline);
    }

    final SyncEvent event = repository.events.single;
    expect(event.status, SyncStatus.failed);
    expect(event.retryCount, AppConstants.syncEventMaxRetries);
    expect(event.lastError, isNotNull);
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
      transport: _EchoTransport(
        remoteUpdatedAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );

    expect(result.failed, 0);
    expect(result.succeeded, 1);
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
      transport: _EchoTransport(
        remoteUpdatedAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );

    expect(result.conflicts, 1);
    expect(result.succeeded, 0);
    expect(repository.events.single.lastError, 'manual_merge_required');
    expect(repository.events.single.status, SyncStatus.pending);
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

