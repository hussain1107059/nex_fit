import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/activity_metrics.dart';
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
  ];
}

/// Drives a single GPS session: permission handling, fix filtering, live
/// metrics, pause/resume and persistence.
class ActivityTrackingController
    extends AutoDisposeNotifier<ActivityTrackingState> {
  Timer? _timer;
  StreamSubscription<ActivityPoint>? _subscription;
  bool _disposed = false;
  int _generation = 0;

  LocationService get _location => ref.read(locationServiceProvider);

  @override
  ActivityTrackingState build() {
    ref.onDispose(() {
      _disposed = true;
      _cancel();
    });
    return const ActivityTrackingState();
  }

  /// Requests permission and starts tracking [type].
  Future<void> start(ActivityType type) async {
    if (state.isActive) return;

    _cancel();
    final int generation = ++_generation;
    final AppUser? user = ref.read(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      state = ActivityTrackingState(
        type: type,
        failure: LocationFailure.unavailable,
      );
      return;
    }

    state = ActivityTrackingState(
      type: type,
      status: ActivityTrackingStatus.acquiring,
    );

    try {
      await _location.ensureReady();
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
      );
      _listen();
      _startTimer();
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

  /// Pauses location updates and the elapsed-time timer.
  void pause() {
    if (state.status != ActivityTrackingStatus.tracking) return;
    _subscription?.cancel();
    _subscription = null;
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
    final DateTime startedAt = state.startedAt ?? DateTime.now();

    if (state.route.length < 2 || state.distanceMeters < 5) {
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

  /// Drops the current run without saving.
  void discard() {
    _generation++;
    _cancel();
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
