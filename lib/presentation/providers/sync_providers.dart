import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/sync/sync_engine.dart';
import '../../domain/entities/app_user.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';
import 'settings_providers.dart';

/// What the offline sync engine is doing right now.
enum SyncActivity { idle, syncing }

/// State of the offline sync queue shown on the dashboard and in settings.
class SyncUiState {
  const SyncUiState({
    this.activity = SyncActivity.idle,
    this.snapshot,
    this.failure,
  });

  final SyncActivity activity;
  final SyncQueueSnapshot? snapshot;
  final Object? failure;

  bool get isSyncing => activity == SyncActivity.syncing;

  SyncUiState copyWith({
    SyncActivity? activity,
    SyncQueueSnapshot? snapshot,
    Object? failure,
    bool clearFailure = false,
  }) {
    return SyncUiState(
      activity: activity ?? this.activity,
      snapshot: snapshot ?? this.snapshot,
      failure: clearFailure ? null : (failure ?? this.failure),
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
      state = state.copyWith(snapshot: const SyncQueueSnapshot());
      return;
    }
    state = state.copyWith(snapshot: await _engine.snapshot(userId));
  }

  /// Processes the pending queue. Without a cloud transport events are
  /// acknowledged locally (offline-first).
  Future<void> runSync() async {
    final String? userId = _userId();
    if (userId == null) return;
    state = state.copyWith(activity: SyncActivity.syncing, clearFailure: true);
    try {
      final SyncRunResult result = await _engine.processQueue(userId);
      await ref
          .read(settingsControllerProvider.notifier)
          .setLastSyncAt(DateTime.now());
      state = state.copyWith(
        activity: SyncActivity.idle,
        snapshot: await _engine.snapshot(userId),
      );
      if (result.hasErrors) {
        state = state.copyWith(failure: result);
      }
    } catch (error) {
      state = state.copyWith(
        activity: SyncActivity.idle,
        failure: error,
      );
    }
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncUiState>(
  SyncController.new,
);
