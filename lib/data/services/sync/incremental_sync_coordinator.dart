import 'dart:async';

import 'package:logging/logging.dart';

import 'sync_log.dart';

/// Why an incremental sync run was requested. Used for diagnostics only — every
/// trigger funnels into the same cursor-based pull, so a missed [realtime]
/// event is always recovered by [startup], [resume] or [manual].
enum SyncTrigger {
  /// First sync after app launch.
  startup,

  /// App returned to the foreground.
  resume,

  /// User just signed in on this device.
  login,

  /// Connectivity changed from offline to online.
  networkRecovery,

  /// Supabase Realtime delivered a postgres change notification.
  realtime,

  /// Explicit user action in the settings / health UI.
  manual,
}

/// Event-driven trigger hub for incremental synchronization (PROMPT 18).
///
/// Realtime and lifecycle events can fire in bursts (a batch of rows edited on
/// another device, resume + connectivity + realtime colliding). The coordinator
/// coalesces them:
///
/// * **Debounce** — bursts within [debounce] collapse into one run.
/// * **Single-flight** — while a run is executing a new request is queued and
///   executed once the current run finishes, so a change that arrived mid-run
///   is never lost.
/// * **Gating** — requests are dropped while [canSync] is false (signed out or
///   offline-first build), which is what makes "missed realtime" safe: the next
///   startup/resume/manual run recovers it from the cursor.
///
/// This class deliberately knows nothing about the transport, the outbox or
/// Supabase; the caller injects [onSync]. Realtime is a pure notification
/// accelerator — it never mutates state and never advances the cursor, so the
/// authoritative cursor sync can never double-apply a change.
class IncrementalSyncCoordinator {
  IncrementalSyncCoordinator({
    required this.onSync,
    required this.canSync,
    this.debounce = const Duration(milliseconds: 750),
    Logger? logger,
  }) : _logger = logger ?? Logger('IncrementalSyncCoordinator');

  /// Executes the actual sync. Awaiting the returned future lets the
  /// coordinator serialize runs.
  final Future<void> Function(SyncTrigger trigger) onSync;

  /// True when a sync may run right now (a user is signed in). Network
  /// availability is *not* part of this check — the sync layer handles offline
  /// locally — but it keeps the hub silent on the login screen.
  final bool Function() canSync;

  final Duration debounce;
  final Logger _logger;

  Timer? _timer;
  SyncTrigger? _pending;
  SyncTrigger? _queuedTrigger;
  bool _running = false;

  /// Whether a run is currently executing.
  bool get isRunning => _running;

  /// The trigger of the debounced run that is about to fire, if any.
  SyncTrigger? get pendingTrigger => _pending;

  /// Schedules an incremental sync after [debounce]. No-op when [canSync] is
  /// false or the debounce window absorbs an identical earlier request.
  void requestSync(SyncTrigger trigger) {
    if (!canSync()) return;
    _pending = trigger;
    _timer?.cancel();
    _timer = Timer(debounce, () => _start());
  }

  /// Runs any pending debounced request immediately. Used on shutdown so a
  /// queued realtime event is not dropped, and in tests to avoid waiting on the
  /// real timer.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_pending == null) return;
    await _start();
  }

  Future<void> _start() async {
    _timer?.cancel();
    _timer = null;
    if (!canSync()) {
      _pending = null;
      return;
    }
    final SyncTrigger trigger = _pending ?? SyncTrigger.manual;
    _pending = null;

    // A request arrived while a run was in flight: remember it and run again
    // as soon as the current run completes (single-flight + coalescing).
    if (_running) {
      _queuedTrigger = trigger;
      SyncLog.info(
        _logger,
        SyncLog.start,
        'sync already running; queueing ${trigger.name}',
      );
      return;
    }

    _running = true;
    try {
      await onSync(trigger);
    } catch (error, stackTrace) {
      _logger.warning(
        '[${SyncLog.start}] ${trigger.name} run failed: $error',
        error,
        stackTrace,
      );
    } finally {
      _running = false;
      final SyncTrigger? queued = _queuedTrigger;
      _queuedTrigger = null;
      if (queued != null && canSync()) {
        unawaited(_start());
      }
    }
  }

  /// Cancels the pending timer and drops queued work. Safe to call multiple
  /// times; does not interrupt a run already in flight.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    _queuedTrigger = null;
  }
}
