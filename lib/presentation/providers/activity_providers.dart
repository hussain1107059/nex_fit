import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/utils/activity_metrics.dart';
import '../../data/services/audio/activity_alert_service.dart';
import '../../data/services/location/location_service.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/app_user.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';

/// Lifecycle of a GPS tracking session.
enum ActivityTrackingStatus {
  idle,
  acquiring,
  tracking,
  paused,
  saving,
  finished,
}

/// Immutable snapshot consumed by the tracking screen.
class ActivityTrackingState extends Equatable {
  const ActivityTrackingState({
    this.type = ActivityType.walking,
    this.status = ActivityTrackingStatus.idle,
    this.route = const <ActivityPoint>[],
    this.elapsedSeconds = 0,
    this.distanceMeters = 0,
    this.currentSpeedMps = 0,
    this.maxSpeedMps = 0,
    this.elevationGainMeters = 0,
    this.weightKg = 70,
    this.failure,
    this.saveFailed = false,
    this.savedSessionId,
    this.startedAt,
    this.goal,
    this.steps = 0,
    this.goalReached = false,
    this.goalAlertPlaying = false,
    this.stepSensorUnavailable = false,
  });

  final ActivityType type;
  final ActivityTrackingStatus status;
  final List<ActivityPoint> route;
  final int elapsedSeconds;
  final double distanceMeters;
  final double currentSpeedMps;
  final double maxSpeedMps;
  final double elevationGainMeters;
  final double weightKg;
  final LocationFailure? failure;
  final bool saveFailed;
  final int? savedSessionId;
  final DateTime? startedAt;
  final ActivityGoal? goal;
  final int steps;
  final bool goalReached;
  final bool goalAlertPlaying;
  final bool stepSensorUnavailable;

  bool get isActive =>
      status == ActivityTrackingStatus.acquiring ||
      status == ActivityTrackingStatus.tracking ||
      status == ActivityTrackingStatus.paused ||
      status == ActivityTrackingStatus.saving;

  bool get hasRoute => route.length > 1;

  double get distanceKm => distanceMeters / 1000;

  double get speedKmh => currentSpeedMps * 3.6;

  double get caloriesBurned => ActivityMetrics.estimateCalories(
    type: type,
    durationSeconds: elapsedSeconds,
    weightKg: weightKg,
  );

  double? get paceSecondsPerKm =>
      distanceMeters > 5 ? elapsedSeconds / distanceKm : null;

  /// Fraction (0-1) of the active target that has been completed, or null
  /// when the session has no target yet.
  double? get goalProgress {
    final ActivityGoal? target = goal;
    if (target == null || target.value <= 0) return null;
    final double current = target.isDistance
        ? distanceMeters
        : steps.toDouble();
    return (current / target.value).clamp(0, 1).toDouble();
  }

  ActivityTrackingState copyWith({
    ActivityType? type,
    ActivityTrackingStatus? status,
    List<ActivityPoint>? route,
    int? elapsedSeconds,
    double? distanceMeters,
    double? currentSpeedMps,
    double? maxSpeedMps,
    double? elevationGainMeters,
    double? weightKg,
    LocationFailure? failure,
    bool clearFailure = false,
    bool? saveFailed,
    int? savedSessionId,
    bool clearSavedSessionId = false,
    DateTime? startedAt,
    ActivityGoal? goal,
    int? steps,
    bool? goalReached,
    bool? goalAlertPlaying,
    bool? stepSensorUnavailable,
  }) {
    return ActivityTrackingState(
      type: type ?? this.type,
      status: status ?? this.status,
      route: route ?? this.route,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      currentSpeedMps: currentSpeedMps ?? this.currentSpeedMps,
      maxSpeedMps: maxSpeedMps ?? this.maxSpeedMps,
      elevationGainMeters: elevationGainMeters ?? this.elevationGainMeters,
      weightKg: weightKg ?? this.weightKg,
      failure: clearFailure ? null : (failure ?? this.failure),
      saveFailed: saveFailed ?? this.saveFailed,
      savedSessionId: clearSavedSessionId
          ? null
          : (savedSessionId ?? this.savedSessionId),
      startedAt: startedAt ?? this.startedAt,
      goal: goal ?? this.goal,
      steps: steps ?? this.steps,
      goalReached: goalReached ?? this.goalReached,
      goalAlertPlaying: goalAlertPlaying ?? this.goalAlertPlaying,
      stepSensorUnavailable:
          stepSensorUnavailable ?? this.stepSensorUnavailable,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    type,
    status,
    route,
    elapsedSeconds,
    distanceMeters,
    currentSpeedMps,
    maxSpeedMps,
    elevationGainMeters,
    weightKg,
    failure,
    saveFailed,
    savedSessionId,
    startedAt,
    goal,
    steps,
    goalReached,
    goalAlertPlaying,
    stepSensorUnavailable,
  ];
}

/// Drives a single GPS session: permission handling, fix filtering, live
/// metrics, pause/resume and persistence.
class ActivityTrackingController
    extends AutoDisposeNotifier<ActivityTrackingState> {
  Timer? _timer;
  StreamSubscription<ActivityPoint>? _subscription;
  StreamSubscription<StepCount>? _stepSubscription;
  int? _stepBaseline;
  bool _disposed = false;
  int _generation = 0;

  LocationService get _location => ref.read(locationServiceProvider);

  ActivityAlertService get _alert => ref.read(activityAlertServiceProvider);

  @override
  ActivityTrackingState build() {
    ref.onDispose(() {
      _disposed = true;
      _cancel();
      unawaited(_alert.stop());
    });
    return const ActivityTrackingState();
  }

  /// Requests permission and starts tracking [type] with an optional [goal].
  ///
  /// Step targets are only honoured for activities that can count steps
  /// (everything except swimming).
  Future<void> start(ActivityType type, {ActivityGoal? goal}) async {
    if (state.isActive) return;

    _cancel();
    final int generation = ++_generation;
    final ActivityGoal? effectiveGoal =
        goal?.isSteps == true && !type.supportsStepTarget ? null : goal;
    final AppUser? user = ref.read(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      state = ActivityTrackingState(
        type: type,
        goal: effectiveGoal,
        failure: LocationFailure.unavailable,
      );
      return;
    }

    state = ActivityTrackingState(
      type: type,
      goal: effectiveGoal,
      status: ActivityTrackingStatus.acquiring,
    );

    try {
      await _location.ensureReady();
      if (_disposed || generation != _generation) return;
      final bool wantsSteps = effectiveGoal?.isSteps == true;
      final bool stepsAllowed = wantsSteps && await _ensureStepPermission();
      if (_disposed || generation != _generation) return;
      final double weightKg = await _loadWeight(user.id);
      final ActivityPoint? firstFix = await _location.currentPoint();
      if (_disposed || generation != _generation) return;

      state = state.copyWith(
        status: ActivityTrackingStatus.tracking,
        startedAt: DateTime.now(),
        weightKg: weightKg,
        route: firstFix == null
            ? const <ActivityPoint>[]
            : <ActivityPoint>[firstFix],
        stepSensorUnavailable: wantsSteps && !stepsAllowed,
      );
      _listen();
      _startTimer();
      if (stepsAllowed) _subscribeSteps();
      _evaluateGoal();
    } on LocationException catch (error) {
      if (_disposed || generation != _generation) return;
      state = state.copyWith(
        status: ActivityTrackingStatus.idle,
        failure: error.failure,
      );
    } on Exception {
      if (_disposed || generation != _generation) return;
      state = state.copyWith(
        status: ActivityTrackingStatus.idle,
        failure: LocationFailure.unavailable,
      );
    }
  }

  /// Pauses location, step and elapsed-time updates.
  void pause() {
    if (state.status != ActivityTrackingStatus.tracking) return;
    if (state.goalAlertPlaying) {
      stopGoalAlert();
    }
    _subscription?.cancel();
    _subscription = null;
    _stepSubscription?.cancel();
    _stepSubscription = null;
    _stepBaseline = null;
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(
      status: ActivityTrackingStatus.paused,
      currentSpeedMps: 0,
    );
  }

  /// Resumes after a pause without resetting accumulated metrics.
  Future<void> resume() async {
    if (state.status != ActivityTrackingStatus.paused) return;
    try {
      await _location.ensureReady();
      if (_disposed) return;
      state = state.copyWith(
        status: ActivityTrackingStatus.tracking,
        clearFailure: true,
      );
      _listen();
      _startTimer();
      if (state.goal?.isSteps == true && !state.stepSensorUnavailable) {
        _subscribeSteps();
      }
    } on LocationException catch (error) {
      if (_disposed) return;
      state = state.copyWith(failure: error.failure);
    }
  }

  /// Stops tracking and persists the session.
  ///
  /// Returns the new session id, or null when the run was too short to keep.
  Future<int?> finish() async {
    if (state.status != ActivityTrackingStatus.tracking &&
        state.status != ActivityTrackingStatus.paused) {
      return state.savedSessionId;
    }

    _cancel();
    stopGoalAlert();
    final DateTime startedAt = state.startedAt ?? DateTime.now();

    final bool tooShort =
        (state.route.length < 2 || state.distanceMeters < 5) &&
        state.steps == 0;
    if (tooShort) {
      state = state.copyWith(status: ActivityTrackingStatus.paused);
      return null;
    }

    state = state.copyWith(status: ActivityTrackingStatus.saving);
    final AppUser? user = ref.read(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      state = state.copyWith(
        status: ActivityTrackingStatus.paused,
        saveFailed: true,
      );
      return null;
    }

    final int duration = math.max(1, state.elapsedSeconds);
    final double avgSpeed = state.distanceMeters / duration;
    final ActivitySession session = ActivitySession(
      userId: user.id,
      type: state.type,
      startedAt: startedAt,
      endedAt: DateTime.now(),
      durationSeconds: duration,
      distanceMeters: state.distanceMeters,
      caloriesBurned: state.caloriesBurned,
      elevationGainMeters: state.elevationGainMeters,
      avgSpeedMps: avgSpeed,
      maxSpeedMps: math.max(state.maxSpeedMps, avgSpeed),
      steps: state.steps,
      goalType: state.goal?.type,
      goalValue: state.goal?.value,
      goalReached: state.goalReached,
      route: state.route,
      createdAt: DateTime.now(),
    );

    try {
      final int id = await ref.read(activityRepositoryProvider).insert(session);
      if (_disposed) return id;
      state = state.copyWith(
        status: ActivityTrackingStatus.finished,
        savedSessionId: id,
      );
      ref.invalidate(activityHistoryProvider);
      ref.invalidate(activityStatsProvider);
      return id;
    } on Exception {
      if (_disposed) return null;
      state = state.copyWith(
        status: ActivityTrackingStatus.paused,
        saveFailed: true,
      );
      return null;
    }
  }

  /// Cancels the looping target-reached chime; tracking keeps running.
  void stopGoalAlert() {
    if (!state.goalAlertPlaying) {
      unawaited(_alert.stop());
      return;
    }
    state = state.copyWith(goalAlertPlaying: false);
    unawaited(_alert.stop());
  }

  /// Drops the current run without saving.
  void discard() {
    _generation++;
    _cancel();
    unawaited(_alert.stop());
    state = const ActivityTrackingState();
  }

  Future<double> _loadWeight(String userId) async {
    try {
      final profile = await ref
          .read(userFitnessProfileRepositoryProvider)
          .getById(userId);
      return profile?.weightKg ?? 70;
    } on Exception {
      return 70;
    }
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = _location.positionStream().listen(
      _onPoint,
      onError: (Object _) {},
    );
  }

  void _onPoint(ActivityPoint point) {
    if (state.status != ActivityTrackingStatus.tracking) return;

    final double? accuracy = point.accuracy;
    if (accuracy != null && accuracy > 35) return;

    final ActivityPoint? last = state.route.isEmpty ? null : state.route.last;

    double segmentMeters = 0;
    double segmentSpeed = 0;
    if (last != null) {
      segmentMeters = ActivityMetrics.haversineMeters(
        last.latitude,
        last.longitude,
        point.latitude,
        point.longitude,
      );
      final int elapsedMs = point.recordedAt
          .difference(last.recordedAt)
          .inMilliseconds;
      if (segmentMeters < _minMoveMeters(state.type)) return;
      if (elapsedMs > 0) {
        segmentSpeed = segmentMeters / (elapsedMs / 1000);
        if (segmentSpeed > 35) return;
      }
    }

    final double? reportedSpeed = point.speed;
    if (reportedSpeed != null && reportedSpeed > 35) return;

    double elevationDelta = 0;
    final double? altitude = point.altitude;
    final double? lastAltitude = last?.altitude;
    if (altitude != null && lastAltitude != null) {
      final double delta = altitude - lastAltitude;
      if (delta >= 1) elevationDelta = delta;
    }

    final double effectiveSpeed = reportedSpeed != null && reportedSpeed > 0.3
        ? reportedSpeed
        : segmentSpeed;

    state = state.copyWith(
      route: <ActivityPoint>[...state.route, point],
      distanceMeters: state.distanceMeters + segmentMeters,
      currentSpeedMps: effectiveSpeed,
      maxSpeedMps: math.max(state.maxSpeedMps, effectiveSpeed),
      elevationGainMeters: state.elevationGainMeters + elevationDelta,
    );
    _evaluateGoal();
  }

  /// Android 10+ needs a runtime activity-recognition grant before the step
  /// counter can be read. iOS prompts through CoreMotion on first use.
  Future<bool> _ensureStepPermission() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final PermissionStatus status = await Permission.activityRecognition
          .request();
      return status.isGranted;
    }
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _subscribeSteps() {
    _stepSubscription?.cancel();
    _stepBaseline = null;
    _stepSubscription = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: (Object _) {
        if (_disposed) return;
        state = state.copyWith(stepSensorUnavailable: true);
      },
    );
  }

  void _onStepCount(StepCount event) {
    if (state.status != ActivityTrackingStatus.tracking) return;

    final int total = event.steps;
    final int? baseline = _stepBaseline;
    if (baseline == null || total < baseline) {
      _stepBaseline = total - state.steps;
      return;
    }
    final int steps = total - baseline;
    if (steps == state.steps) return;
    state = state.copyWith(steps: steps);
    _evaluateGoal();
  }

  /// Starts the looping chime exactly once when the target is first met.
  void _evaluateGoal() {
    final ActivityGoal? goal = state.goal;
    if (goal == null || state.goalReached) return;
    if (!goal.isReached(
      distanceMeters: state.distanceMeters,
      steps: state.steps,
    )) {
      return;
    }
    state = state.copyWith(goalReached: true, goalAlertPlaying: true);
    unawaited(_alert.start());
    unawaited(HapticFeedback.heavyImpact());
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (state.status != ActivityTrackingStatus.tracking) return;
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _subscription?.cancel();
    _subscription = null;
    _stepSubscription?.cancel();
    _stepSubscription = null;
    _stepBaseline = null;
  }

  static double _minMoveMeters(ActivityType type) => switch (type) {
    ActivityType.walking => 2,
    ActivityType.running => 2.5,
    ActivityType.cycling => 4,
    ActivityType.swimming => 3,
  };
}

final activityTrackingControllerProvider =
    NotifierProvider.autoDispose<
      ActivityTrackingController,
      ActivityTrackingState
    >(ActivityTrackingController.new);

/// Recent sessions for the signed-in user.
final activityHistoryProvider =
    FutureProvider.autoDispose<List<ActivitySession>>((ref) {
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) {
        return const <ActivitySession>[];
      }
      return ref
          .watch(activityRepositoryProvider)
          .getByUserId(user.id, limit: 50);
    });

/// Lifetime aggregate for the activity home header.
final activityStatsProvider = FutureProvider.autoDispose<ActivityStats>((ref) {
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) {
    return const ActivityStats();
  }
  return ref.watch(activityRepositoryProvider).getStats(user.id);
});

/// A single session (with its GPS trace) for the detail screen.
final activitySessionProvider = FutureProvider.autoDispose
    .family<ActivitySession?, int>((ref, int id) {
      return ref.watch(activityRepositoryProvider).getById(id);
    });
