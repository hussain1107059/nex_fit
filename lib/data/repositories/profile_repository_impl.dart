import '../../domain/entities/app_user.dart';
import '../../domain/entities/common_enums.dart';
import '../../domain/entities/profile_data.dart';
import '../../domain/entities/step_log.dart';
import '../../domain/entities/streak.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/water_log.dart';
import '../../domain/entities/weight_log.dart';
import '../../domain/entities/workout_history.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/step_log_repository.dart';
import '../../domain/repositories/streak_repository.dart';
import '../../domain/repositories/water_log_repository.dart';
import '../../domain/repositories/weight_log_repository.dart';
import '../../domain/repositories/workout_history_repository.dart';
import '../datasources/local/user_local_data_source.dart';
import '../datasources/local/user_profile_local_data_source.dart';

/// SQLite backed implementation of [ProfileRepository].
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({
    required this._userDataSource,
    required this._profileDataSource,
    required this._workoutHistoryRepository,
    required this._streakRepository,
    required this._waterLogRepository,
    required this._weightLogRepository,
    required this._stepLogRepository,
  });

  final UserLocalDataSource _userDataSource;
  final UserProfileLocalDataSource _profileDataSource;
  final WorkoutHistoryRepository _workoutHistoryRepository;
  final StreakRepository _streakRepository;
  final WaterLogRepository _waterLogRepository;
  final WeightLogRepository _weightLogRepository;
  final StepLogRepository _stepLogRepository;

  @override
  Future<ProfileData> load(String userId) async {
    final List<Object?> results = await Future.wait<Object?>([
      _userDataSource.getProfile(userId),
      _profileDataSource.getById(userId),
      _workoutHistoryRepository.getByUserId(userId),
      _streakRepository.getByUserId(userId),
      _waterLogRepository.getByUserId(userId),
      _weightLogRepository.getByUserId(userId),
      _stepLogRepository.getByUserId(userId),
    ]);

    final AppUser? user = results[0] as AppUser?;
    final UserProfile? profile = results[1] as UserProfile?;
    final List<WorkoutHistory> workouts = results[2] as List<WorkoutHistory>;
    final List<Streak> streaks = results[3] as List<Streak>;
    final List<WaterLog> waterLogs = results[4] as List<WaterLog>;
    final List<WeightLog> weightLogs = results[5] as List<WeightLog>;
    final List<StepLog> stepLogs = results[6] as List<StepLog>;

    final Streak? workoutStreak = streaks
        .where((Streak s) => s.streakType == StreakType.workout)
        .firstOrNull;
    final int longestStreak = streaks.fold(
      0,
      (int longest, Streak s) =>
          s.longestStreak > longest ? s.longestStreak : longest,
    );

    final double caloriesBurned =
        workouts.fold(
          0.0,
          (double sum, WorkoutHistory w) => sum + (w.caloriesBurn ?? 0.0),
        ) +
        stepLogs.fold<double>(
          0.0,
          (double sum, StepLog s) => sum + s.caloriesBurned,
        );
    final int waterIntakeMl = waterLogs.fold(
      0,
      (int sum, WaterLog w) => sum + w.amountMl,
    );

    double? weightLostKg;
    if (weightLogs.length >= 2) {
      // Rows arrive newest first, so the oldest measurement is last.
      weightLostKg = weightLogs.last.weightKg - weightLogs.first.weightKg;
    }

    return ProfileData(
      user: user ?? AppUser.signedOut,
      profile: profile,
      stats: ProfileStats(
        totalWorkouts: workouts.length,
        currentStreak: workoutStreak?.currentStreak ?? 0,
        longestStreak: longestStreak,
        caloriesBurned: caloriesBurned,
        waterIntakeMl: waterIntakeMl,
        weightLostKg: weightLostKg,
      ),
    );
  }

  @override
  Future<void> saveProfile(UserProfile profile) {
    return _profileDataSource.upsert(profile);
  }

  @override
  Future<UserProfile?> getProfile(String userId) {
    return _profileDataSource.getById(userId);
  }

  @override
  Future<void> updateName(String userId, String name) async {
    final AppUser? user = await _userDataSource.getProfile(userId);
    if (user == null) return;
    await _userDataSource.saveProfile(user.copyWith(displayName: name));
  }
}
