import '../../../domain/entities/sync_state.dart';
import '../../../domain/repositories/sync_state_repository.dart';
import '../../datasources/local/app_database.dart';
import 'local_data_ownership.dart';
import 'remote_change_applier.dart';
import 'sync_engine.dart';

/// Phase of a first-time (initial) user sync (PROMPT 17).
enum InitialSyncPhase { idle, syncing, complete, failed, offline }

/// Progress snapshot emitted during an initial sync run.
class InitialSyncProgress {
  const InitialSyncProgress({
    required this.phase,
    this.stage = 'idle',
    this.changesPulled = 0,
    this.eventsPushed = 0,
    this.error,
  });

  final InitialSyncPhase phase;
  final String stage;
  final int changesPulled;
  final int eventsPushed;
  final Object? error;

  InitialSyncProgress copyWith({
    InitialSyncPhase? phase,
    String? stage,
    int? changesPulled,
    int? eventsPushed,
    Object? error,
  }) {
    return InitialSyncProgress(
      phase: phase ?? this.phase,
      stage: stage ?? this.stage,
      changesPulled: changesPulled ?? this.changesPulled,
      eventsPushed: eventsPushed ?? this.eventsPushed,
      error: error ?? this.error,
    );
  }
}

/// Result of a single initial sync run.
class InitialSyncResult {
  const InitialSyncResult({
    required this.phase,
    this.changesPulled = 0,
    this.eventsPushed = 0,
    this.error,
    this.alreadyComplete = false,
    this.analysis,
  });

  final InitialSyncPhase phase;
  final int changesPulled;
  final int eventsPushed;
  final Object? error;

  /// True when the sync_state already reported initial sync complete.
  final bool alreadyComplete;

  /// Ownership classification of local data taken after a successful run.
  final OwnershipAnalysis? analysis;

  bool get success => phase == InitialSyncPhase.complete;
}

/// First-time user synchronization (PROMPT 17).
///
/// Order of operations:
/// 1. Ensure the authenticated user's profile exists locally.
/// 2. Load `sync_state`; if initial sync already completed, report so and stop.
/// 3. When the transport is not ready, report an offline phase without touching
///    local data or marking sync complete (it can retry later).
/// 4. Pull the user's cloud rows (initializes the per-user cursor and marks
///    initial sync complete on a fully-successful pull).
/// 5. Push this user's own pending local records.
///
/// Pre-existing local data is never deleted and never silently uploaded for
/// another account: another account's rows are left untouched, and orphaned
/// rows are only adopted through an explicit opt-in call
/// ([LocalDataOwnershipAnalyzer.adoptOrphans]).
class InitialSyncService {
  InitialSyncService({
    required this.database,
    required this.engine,
    required this.transport,
    required this.applier,
    required this.ownershipAnalyzer,
    required this.syncStateRepository,
  });

  final AppDatabase database;
  final SyncEngine engine;
  final SyncTransport transport;
  final RemoteChangeApplier applier;
  final LocalDataOwnershipAnalyzer ownershipAnalyzer;
  final SyncStateRepository syncStateRepository;

  /// Runs the initial user sync for [userId], emitting progress via
  /// [onProgress]. Never deletes local data. [ensureProfile] is an optional
  /// best-effort hook that guarantees the authenticated user's local profile
  /// row exists before the pull starts.
  Future<InitialSyncResult> run({
    required String userId,
    Future<void> Function(String userId)? ensureProfile,
    void Function(InitialSyncProgress progress)? onProgress,
  }) async {
    void emit(
      InitialSyncPhase phase, {
      String stage = 'idle',
      int pulled = 0,
      int pushed = 0,
      Object? error,
    }) {
      onProgress?.call(InitialSyncProgress(
        phase: phase,
        stage: stage,
        changesPulled: pulled,
        eventsPushed: pushed,
        error: error,
      ));
    }

    // 1. Ensure the local profile row exists for the authenticated user
    //    (best-effort; sign-in already persists it in most flows).
    emit(InitialSyncPhase.syncing, stage: 'ensureProfile');
    final Future<void> Function(String userId)? ensure = ensureProfile;
    if (ensure != null) {
      try {
        await ensure(userId);
      } catch (_) {
        // Profile creation is best-effort; sync continues regardless.
      }
    }
    // 2. Detect whether initial sync already completed.
    emit(InitialSyncPhase.syncing, stage: 'loadState');
    final SyncState? state = await syncStateRepository.getByUserId(userId);
    if (state != null && state.initialSyncCompleted) {
      emit(InitialSyncPhase.complete, stage: 'alreadyComplete');
      return InitialSyncResult(
        phase: InitialSyncPhase.complete,
        alreadyComplete: true,
      );
    }

    // 3. Offline detection: do not touch data, do not mark complete.
    if (!transport.isReady) {
      emit(InitialSyncPhase.offline, stage: 'offline');
      return const InitialSyncResult(phase: InitialSyncPhase.offline);
    }

    // 4. Pull cloud user rows. A fully-successful pull advances the cursor and
    //    marks initial sync complete (Part 11); any failure rolls back the
    //    batch and leaves the state untouched so it can be retried.
    emit(InitialSyncPhase.syncing, stage: 'pull');
    int pulled = 0;
    try {
      // drainToEnd drains the remote paginator to exhaustion (PROMPT 20) so a
      // first sync of >5,000 rows completes in one run instead of stopping at
      // the incremental batch cap. The per-batch cursor transaction keeps
      // resumability: an interrupt rolls back and the next run resumes.
      pulled = await engine.pull(
        userId: userId,
        transport: transport,
        applier: applier,
        drainToEnd: true,
        onBatchProgress: (int applied, int cursor) {
          emit(InitialSyncPhase.syncing, stage: 'pull', pulled: applied);
        },
      );
    } on SyncTransportException catch (error) {
      emit(InitialSyncPhase.failed, stage: 'pull', error: error);
      return InitialSyncResult(phase: InitialSyncPhase.failed, error: error);
    } on UnsupportedTableException catch (error) {
      emit(InitialSyncPhase.failed, stage: 'pull', error: error);
      return InitialSyncResult(phase: InitialSyncPhase.failed, error: error);
    }

    // 5. Push this user's own pending records. The outbox is user-scoped, so a
    //    previous account's events are never uploaded here. A push failure is
    //    not fatal to completion: pending events retry on the next run.
    emit(InitialSyncPhase.syncing, stage: 'push');
    var pushed = 0;
    try {
      final SyncRunResult push = await engine.processQueue(
        userId,
        transport: transport,
      );
      pushed = push.succeeded;
    } catch (_) {
      // Non-fatal; events stay pending and retry.
    }

    // 6. Report completion and surface ownership of local data.
    emit(
      InitialSyncPhase.complete,
      stage: 'complete',
      pulled: pulled,
      pushed: pushed,
    );
    return InitialSyncResult(
      phase: InitialSyncPhase.complete,
      changesPulled: pulled,
      eventsPushed: pushed,
      analysis: await _analyze(userId),
    );
  }

  Future<OwnershipAnalysis> analyzeOwnership(String userId) =>
      ownershipAnalyzer.analyze(userId);

  /// Explicit opt-in adoption of orphaned local rows (never automatic).
  Future<LocalDataAdoptionResult> adoptOrphans(String userId) =>
      ownershipAnalyzer.adoptOrphans(userId: userId);

  Future<OwnershipAnalysis?> _analyze(String userId) async {
    try {
      return await ownershipAnalyzer.analyze(userId);
    } catch (_) {
      return null;
    }
  }
}