import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/sync/incremental_sync_coordinator.dart';
import '../../data/services/sync/initial_sync_service.dart';
import '../../data/services/sync/local_data_ownership.dart';
import '../../data/services/sync/master_data_contracts.dart';
import '../../data/services/sync/sync_engine.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/sync_state.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';
import 'reminder_providers.dart';
import 'settings_providers.dart';

/// What the offline sync engine is doing right now.
enum SyncActivity { idle, syncing }

/// State of the offline sync queue shown on the dashboard and in settings.
class SyncUiState {
  const SyncUiState({
    this.activity = SyncActivity.idle,
    this.snapshot,
    this.failure,
    this.initialPhase = InitialSyncPhase.idle,
    this.initialChangesPulled = 0,
    this.initialEventsPushed = 0,
    this.initialAnalysis,
    this.pendingConflictCount = 0,
    this.resetAt,
    this.resetPulled = 0,
    this.resetTables,
    this.resetError,
  });

  final SyncActivity activity;
  final SyncQueueSnapshot? snapshot;
  final Object? failure;

  /// First-time sync phase (PROMPT 17). Surfaced so the UI can show
  /// syncing/progress/completed/failed/offline states during onboarding.
  final InitialSyncPhase initialPhase;
  final int initialChangesPulled;
  final int initialEventsPushed;
  final OwnershipAnalysis? initialAnalysis;

  /// Unresolved manual-merge conflicts in the durable store (PROMPT 19).
  final int pendingConflictCount;

  /// When the last full re-sync ran, how many remote changes it re-applied
  /// and (if it failed) the error. Surfaces in developer diagnostics so a
  /// stale device can be verified end-to-end.
  final DateTime? resetAt;
  final int resetPulled;

  /// Per-table applied counts from the last full re-sync (formatted string).
  final String? resetTables;
  final Object? resetError;

  bool get isSyncing => activity == SyncActivity.syncing;

  bool get isInitialSyncing => initialPhase == InitialSyncPhase.syncing;

  SyncUiState copyWith({
    SyncActivity? activity,
    SyncQueueSnapshot? snapshot,
    Object? failure,
    InitialSyncPhase? initialPhase,
    int? initialChangesPulled,
    int? initialEventsPushed,
    OwnershipAnalysis? initialAnalysis,
    int? pendingConflictCount,
    DateTime? resetAt,
    int? resetPulled,
    String? resetTables,
    Object? resetError,
    bool clearFailure = false,
    bool clearResetError = false,
  }) {
    return SyncUiState(
      activity: activity ?? this.activity,
      snapshot: snapshot ?? this.snapshot,
      failure: clearFailure ? null : (failure ?? this.failure),
      initialPhase: initialPhase ?? this.initialPhase,
      initialChangesPulled: initialChangesPulled ?? this.initialChangesPulled,
      initialEventsPushed: initialEventsPushed ?? this.initialEventsPushed,
      initialAnalysis: initialAnalysis ?? this.initialAnalysis,
      pendingConflictCount:
          pendingConflictCount ?? this.pendingConflictCount,
      resetAt: resetAt ?? this.resetAt,
      resetPulled: resetPulled ?? this.resetPulled,
      resetTables: resetTables ?? this.resetTables,
      resetError: clearResetError ? null : (resetError ?? this.resetError),
    );
  }
}

/// Drives the offline sync queue: processes pending events, exposes the queue
/// snapshot and records the last sync timestamp in the settings.
class SyncController extends Notifier<SyncUiState> {
  SyncEngine get _engine => ref.read(syncEngineProvider);

  @override
  SyncUiState build() {
    ref.watch(currentUserProvider);
    return const SyncUiState();
  }

  String? _userId() {
    final AppUser? user = ref.read(currentUserProvider);
    if (user == null || !user.isSignedIn) return null;
    return user.id;
  }

  Future<void> refresh() async {
    final String? userId = _userId();
    if (userId == null) {
      state = state.copyWith(
        snapshot: const SyncQueueSnapshot(),
        pendingConflictCount: 0,
      );
      return;
    }
    // Reclaim stuck PROCESSING events on startup (Part 18).
    await _engine.resetStuckProcessingEvents(userId);
    state = state.copyWith(
      snapshot: await _engine.snapshot(userId),
      pendingConflictCount:
          await ref.read(syncConflictRepositoryProvider).countPending(userId),
    );
  }

  /// Processes the pending queue, pulls remote changes after the stored cursor
  /// and refreshes the server-authoritative master catalogs (PROMPT 18).
  ///
  /// On the first run for a user (no `sync_state` or not yet marked complete)
  /// this drives the [InitialSyncService] flow (PROMPT 17): ensure profile,
  /// pull cloud rows, push this user's pending records and surface the
  /// ownership of pre-existing local data. Subsequent runs use the incremental
  /// push + pull path.
  Future<void> runSync({SyncTrigger trigger = SyncTrigger.manual}) async {
    final String? userId = _userId();
    if (userId == null) return;
    // PROMPT 22: never overlap manual syncs — the engine also serializes under
    // a per-user lock, but the UI should not stack progress states or snackbars.
    if (state.isSyncing) return;
    state = state.copyWith(activity: SyncActivity.syncing, clearFailure: true);
    try {
      final bool firstRun = await _isFirstRun(userId);
      if (firstRun) {
        await _runInitialSync(userId);
      } else {
        await _runIncrementalSync(userId);
      }
    } catch (error) {
      state = state.copyWith(
        activity: SyncActivity.idle,
        failure: error,
      );
    }
  }

  Future<bool> _isFirstRun(String userId) async {
    final SyncState? syncState =
        await ref.read(syncStateRepositoryProvider).getByUserId(userId);
    return syncState == null || !syncState.initialSyncCompleted;
  }

  /// Best-effort mirror of the initial-sync `ensureProfile`: writes the
  /// signed-in user into the local `users` table so every `user_profile`
  /// foreign key is resolvable during a pull. Never throws — a failure here
  /// must not block the sync it guards.
  Future<void> _ensureLocalUserRow() async {
    final AppUser? user = ref.read(currentUserProvider);
    if (user == null || !user.isSignedIn) return;
    try {
      await ref.read(userProfileRepositoryProvider).saveProfile(user);
    } catch (_) {
      // The pull safety-net skips unresolvable rows; this is only a parent
      // pre-warm and must never fail the sync run.
    }
  }

  Future<InitialSyncResult> _runInitialSync(String userId) async {
    // Master catalogs must land BEFORE the user pull (PROMPT 16 ordering):
    // user rows reference master uuids (workout_exercise -> exercise,
    // meal_item -> food_item, exercise_favorite -> exercise). A fresh install
    // only carries the server uuids after master sync adopts and stamps the
    // seeded catalogs; pulling first would leave every such foreign key
    // unresolvable and stall the whole initial sync. A best-effort failure here
    // is tolerated (the pull safety-net skips unresolvable rows) but with the
    // catalogs in place the pull converges without data loss.
    await _refreshAndMaster();
    final InitialSyncResult result = await ref
        .read(initialSyncServiceProvider)
        .run(
          userId: userId,
          ensureProfile: (uid) async {
            final AppUser? user = ref.read(currentUserProvider);
            if (user != null && user.isSignedIn && user.id == uid) {
              await ref.read(userProfileRepositoryProvider).saveProfile(user);
            }
          },
          onProgress: (InitialSyncProgress progress) {
            state = state.copyWith(
              initialPhase: progress.phase,
              initialChangesPulled: progress.changesPulled,
              initialEventsPushed: progress.eventsPushed,
            );
          },
        );
    state = state.copyWith(
      activity: SyncActivity.idle,
      initialPhase: result.phase,
      initialChangesPulled: result.changesPulled,
      initialEventsPushed: result.eventsPushed,
      initialAnalysis: result.analysis,
    );
    if (result.success || result.alreadyComplete) {
      ref.read(syncStatusProvider.notifier).markInitialSyncComplete();
      await ref
          .read(settingsControllerProvider.notifier)
          .setLastSyncAt(DateTime.now());
    }
    await _refreshAndMaster();
    // PROMPT 34: the initial pull may have brought reminder rows onto this
    // device for the first time, so schedule their local notifications now
    // instead of waiting for the next app restart.
    await rescheduleRemindersInContainer(ref.container);
    return result;
  }

  Future<void> _runIncrementalSync(String userId) async {
    final SyncTransport transport =
        ref.read(supabaseSyncTransportProvider);
    final SyncRunResult result;
    if (transport.isReady) {
      // A pulled profile row references `user_profile.user_id` -> `users(id)`.
      // Guarantee the parent exists so the apply never hits an unresolvable FK.
      await _ensureLocalUserRow();
      // Push + pull under the per-user lock; the pull cursor only advances
      // after each batch commits.
      result = await _engine.sync(
        userId: userId,
        transport: transport,
        applier: ref.read(remoteChangeApplierProvider),
      );
      if (result.hasPulled) {
        ref.read(syncStatusProvider.notifier).markInitialSyncComplete();
      }
    } else {
      // Transport not ready (offline or Supabase still initializing). Pass the
      // transport anyway so the engine keeps pending events retryable instead
      // of acknowledging them as success — an acked event would never reach
      // the cloud when connectivity returns.
      result = await _engine.processQueue(userId, transport: transport);
    }
    await ref
        .read(settingsControllerProvider.notifier)
        .setLastSyncAt(DateTime.now());
    await _refreshAndMaster();
    // PROMPT 34: reminder configuration is user-owned and syncable while
    // notification execution is device-local. After a pull (or an offline
    // acknowledgement) re-schedule every enabled reminder so reminders that
    // arrived via the cloud are scheduled without an app restart and without
    // duplicating already-scheduled notifications (deterministic id slots).
    await rescheduleRemindersInContainer(ref.container);
    if (result.hasErrors) {
      state = state.copyWith(failure: result);
    }
  }

  /// Master catalogs are global and server-authoritative (PROMPT 16). They run
  /// after the user outbox so a catalog failure never rolls back the user's
  /// pushed changes; the outbox failure, if any, stays authoritative for the
  /// UI status.
  Future<void> _refreshAndMaster() async {
    final String? userId = _userId();
    if (userId == null) return;
    try {
      final MasterDataSyncResult master =
          await ref.read(masterDataSyncServiceProvider).syncAll();
      if (master.hasErrors) {
        state = state.copyWith(failure: master);
      }
    } catch (_) {
      // Keep the outbox result; master errors are retried on the next run.
    }
    state = state.copyWith(
      activity: SyncActivity.idle,
      snapshot: await _engine.snapshot(userId),
      pendingConflictCount:
          await ref.read(syncConflictRepositoryProvider).countPending(userId),
    );
  }

  /// Explicit opt-in adoption of orphaned local rows for the current user
  /// (PROMPT 17). Never automatic; returns the adoption result or null when no
  /// user is signed in.
  Future<LocalDataAdoptionResult?> adoptOrphanedLocalData() async {
    final String? userId = _userId();
    if (userId == null) return null;
    final LocalDataAdoptionResult result =
        await ref.read(initialSyncServiceProvider).adoptOrphans(userId);
    await refresh();
    return result;
  }

  /// Full re-sync: drops the stored pull cursor so the next [runSync]
  /// re-applies every remote change from scratch (parents-first, cursor-atomic).
  /// Used to repair a device whose local rows were written by an older build
  /// or a partial pull. Pending outbox events are preserved and re-pushed.
  ///
  /// Unlike [runSync] this deliberately bypasses the `state.isSyncing` guard:
  /// a full reset must never be silently dropped because a periodic sync is in
  /// flight. The engine's per-user lock makes the cursor reset + re-pull
  /// atomic and serializes with any in-flight run.
  Future<SyncResetResult> resetAndResync() async {
    final String? userId = _userId();
    if (userId == null) return const SyncResetResult();
    final SyncTransport transport = ref.read(supabaseSyncTransportProvider);
    if (!transport.isReady) {
      return const SyncResetResult(
        ran: true,
        deleted: false,
        error: 'transport_not_ready',
      );
    }
    state = state.copyWith(activity: SyncActivity.syncing, clearFailure: true);
    // The pulled profile row references `user_profile.user_id` -> `users(id)`.
    // A device whose `users` row is missing (or was wiped by an account
    // switch / cascade) would otherwise fail every profile apply with an FK
    // violation and the pull safety-net would silently skip it, leaving the
    // profile blank forever. Guarantee the parent row before the re-pull.
    await _ensureLocalUserRow();
    String tables = '';
    try {
      final SyncRunResult result = await _engine.resetAndSync(
        userId: userId,
        transport: transport,
        applier: ref.read(remoteChangeApplierProvider),
        onAppliedByTable: (Map<String, int> applied, int cursor) {
          final List<String> parts = <String>[
            for (final MapEntry<String, int> entry in applied.entries)
              '${entry.key}=${entry.value}',
          ];
          tables = 'cursor=$cursor ${parts.join(' ')}';
        },
      );
      if (result.hasPulled) {
        ref.read(syncStatusProvider.notifier).markInitialSyncComplete();
      }
      await ref
          .read(settingsControllerProvider.notifier)
          .setLastSyncAt(DateTime.now());
      await _refreshAndMaster();
      state = state.copyWith(
        resetAt: DateTime.now(),
        resetPulled: result.pulled,
        resetTables: tables,
        resetError: null,
        clearResetError: true,
      );
      return SyncResetResult(ran: true, deleted: true, pulled: result.pulled);
    } catch (error) {
      state = state.copyWith(
        activity: SyncActivity.idle,
        failure: error,
        resetAt: DateTime.now(),
        resetError: error,
      );
      return SyncResetResult(ran: true, deleted: true, error: error);
    }
  }
}

/// Result of a full re-sync ([SyncController.resetAndResync]).
class SyncResetResult {
  const SyncResetResult({
    this.ran = false,
    this.deleted = false,
    this.pulled = 0,
    this.error,
  });

  /// Whether the reset flow was attempted.
  final bool ran;

  /// Whether the stored pull cursor was actually removed.
  final bool deleted;

  /// Number of remote changes re-applied by the fresh pull.
  final int pulled;

  /// Set when the delete or the fresh pull failed.
  final Object? error;

  bool get success => ran && deleted && error == null;
}

final syncControllerProvider = NotifierProvider<SyncController, SyncUiState>(
  SyncController.new,
);

/// The sync status a consumer should display (Part 19 of the sync foundation).
enum SyncUiStatus {
  idle,
  syncing,
  success,
  offline,
  partialFailure,
  error,
  conflict,
}

/// Live two-way sync status: current status, last sync time and queue counts.
class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.status,
    this.lastSyncAt,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.conflictCount = 0,
    this.pendingConflictCount = 0,
    this.isInitialSyncComplete = false,
  });

  final SyncUiStatus status;
  final DateTime? lastSyncAt;
  final int pendingCount;
  final int failedCount;
  final int conflictCount;

  /// Unresolved manual-merge conflicts in the durable store (PROMPT 19).
  final int pendingConflictCount;
  final bool isInitialSyncComplete;

  SyncStatusSnapshot copyWith({
    SyncUiStatus? status,
    DateTime? lastSyncAt,
    int? pendingCount,
    int? failedCount,
    int? conflictCount,
    int? pendingConflictCount,
    bool? isInitialSyncComplete,
  }) {
    return SyncStatusSnapshot(
      status: status ?? this.status,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      conflictCount: conflictCount ?? this.conflictCount,
      pendingConflictCount:
          pendingConflictCount ?? this.pendingConflictCount,
      isInitialSyncComplete: isInitialSyncComplete ?? this.isInitialSyncComplete,
    );
  }
}

/// Derives the user-facing [SyncUiStatus] from the engine activity, the queue
/// snapshot and the last run result. Tracks whether a full sync (with pull)
/// has ever completed for the user.
class SyncStatusController extends Notifier<SyncStatusSnapshot> {
  bool _initialSyncSeen = false;

  @override
  SyncStatusSnapshot build() {
    final SyncUiState ui = ref.watch(syncControllerProvider);
    final String? userId = ref.watch(currentUserProvider)?.id;
    if (userId == null || !ref.read(currentUserProvider)!.isSignedIn) {
      return const SyncStatusSnapshot(status: SyncUiStatus.offline);
    }

    final SyncQueueSnapshot? snapshot = ui.snapshot;
    final SyncRunResult? failure = ui.failure is SyncRunResult
        ? ui.failure as SyncRunResult
        : null;

    if (ui.isSyncing) {
      return SyncStatusSnapshot(
        status: SyncUiStatus.syncing,
        lastSyncAt: snapshot?.lastSyncedAt,
        pendingCount: snapshot?.pending ?? 0,
        failedCount: snapshot?.failed ?? 0,
        conflictCount: failure?.conflicts ?? 0,
        pendingConflictCount: ui.pendingConflictCount,
        isInitialSyncComplete: _initialSyncSeen,
      );
    }

    // Only UNRESOLVED conflicts that need the user's attention surface the
    // "Conflict needs attention" state. Auto-resolved conflicts (the default
    // `latestWins` / server-won strategy) are recorded for review but are not
    // actionable, so they must not keep the status chip stuck in a conflict
    // state after the run that produced them.
    final bool hasConflicts = ui.pendingConflictCount > 0;
    final SyncUiStatus status;
    if (hasConflicts) {
      status = SyncUiStatus.conflict;
    } else if ((snapshot?.failed ?? 0) > 0) {
      status = SyncUiStatus.error;
    } else if ((snapshot?.pending ?? 0) > 0) {
      status = SyncUiStatus.partialFailure;
    } else if (snapshot?.lastSyncedAt != null || _initialSyncSeen) {
      status = SyncUiStatus.success;
    } else {
      status = SyncUiStatus.idle;
    }

    return SyncStatusSnapshot(
      status: status,
      lastSyncAt: snapshot?.lastSyncedAt,
      pendingCount: snapshot?.pending ?? 0,
      failedCount: snapshot?.failed ?? 0,
      conflictCount: failure?.conflicts ?? 0,
      pendingConflictCount: ui.pendingConflictCount,
      isInitialSyncComplete: _initialSyncSeen,
    );
  }

  /// Marks that a full push+pull sync completed (used after [sync]).
  void markInitialSyncComplete() {
    _initialSyncSeen = true;
    ref.invalidateSelf();
  }
}

final syncStatusProvider =
    NotifierProvider<SyncStatusController, SyncStatusSnapshot>(
      SyncStatusController.new,
    );
