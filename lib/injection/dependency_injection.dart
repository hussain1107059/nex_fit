import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/network_info.dart';
import '../data/datasources/local/app_database.dart';
import '../data/datasources/local/app_settings_local_data_source.dart';
import '../data/datasources/local/achievement_local_data_source.dart';
import '../data/datasources/local/backup_history_local_data_source.dart';
import '../data/datasources/local/badge_local_data_source.dart';
import '../data/datasources/local/challenge_local_data_source.dart';
import '../data/datasources/local/bmi_log_local_data_source.dart';
import '../data/datasources/local/body_measurement_local_data_source.dart';
import '../data/datasources/local/daily_progress_local_data_source.dart';
import '../data/datasources/local/error_log_local_data_source.dart';
import '../data/datasources/local/exercise_history_local_data_source.dart';
import '../data/datasources/local/exercise_local_data_source.dart';
import '../data/datasources/local/fitness_goal_local_data_source.dart';
import '../data/datasources/local/food_item_local_data_source.dart';
import '../data/datasources/local/food_log_local_data_source.dart';
import '../data/datasources/local/level_local_data_source.dart';
import '../data/datasources/local/meal_category_local_data_source.dart';
import '../data/datasources/local/meal_item_local_data_source.dart';
import '../data/datasources/local/meal_local_data_source.dart';
import '../data/datasources/local/reminder_history_local_data_source.dart';
import '../data/datasources/local/reminder_local_data_source.dart';
import '../data/datasources/local/reward_local_data_source.dart';
import '../data/datasources/local/session_local_data_source.dart';
import '../data/datasources/local/sleep_log_local_data_source.dart';
import '../data/datasources/local/step_log_local_data_source.dart';
import '../data/datasources/local/streak_local_data_source.dart';
import '../data/datasources/local/sync_event_local_data_source.dart';
import '../data/datasources/local/user_local_data_source.dart';
import '../data/datasources/local/user_profile_local_data_source.dart';
import '../data/datasources/local/water_log_local_data_source.dart';
import '../data/datasources/local/xp_history_local_data_source.dart';
import '../data/datasources/local/weight_log_local_data_source.dart';
import '../data/datasources/local/workout_category_local_data_source.dart';
import '../data/datasources/local/workout_exercise_local_data_source.dart';
import '../data/datasources/local/workout_history_local_data_source.dart';
import '../data/datasources/local/workout_local_data_source.dart';
import '../data/repositories/app_preferences_repository_impl.dart';
import '../data/repositories/app_settings_repository_impl.dart';
import '../data/repositories/challenge_repository_impl.dart';
import '../data/repositories/dashboard_repository_impl.dart';
import '../data/repositories/global_search_repository_impl.dart';
import '../data/repositories/profile_repository_impl.dart';
import '../data/repositories/progress_analytics_repository_impl.dart';
import '../data/repositories/achievement_repository_impl.dart';
import '../data/repositories/backup_history_repository_impl.dart';
import '../data/repositories/badge_repository_impl.dart';
import '../data/repositories/bmi_log_repository_impl.dart';
import '../data/repositories/body_measurement_repository_impl.dart';
import '../data/repositories/daily_progress_repository_impl.dart';
import '../data/repositories/error_log_repository_impl.dart';
import '../data/repositories/exercise_history_repository_impl.dart';
import '../data/repositories/exercise_repository_impl.dart';
import '../data/repositories/fitness_goal_repository_impl.dart';
import '../data/repositories/food_item_repository_impl.dart';
import '../data/repositories/food_log_repository_impl.dart';
import '../data/repositories/hydration_repository_impl.dart';
import '../data/repositories/level_repository_impl.dart';
import '../data/repositories/meal_category_repository_impl.dart';
import '../data/repositories/meal_item_repository_impl.dart';
import '../data/repositories/meal_repository_impl.dart';
import '../data/repositories/reminder_history_repository_impl.dart';
import '../data/repositories/reminder_repository_impl.dart';
import '../data/repositories/reward_repository_impl.dart';
import '../data/repositories/session_repository_impl.dart';
import '../data/repositories/sleep_log_repository_impl.dart';
import '../data/repositories/smart_reminder_repository_impl.dart';
import '../data/repositories/step_log_repository_impl.dart';
import '../data/repositories/streak_repository_impl.dart';
import '../data/repositories/sync_event_repository_impl.dart';
import '../data/repositories/user_fitness_profile_repository_impl.dart';
import '../data/repositories/xp_history_repository_impl.dart';
import '../data/repositories/user_profile_repository_impl.dart';
import '../data/repositories/water_log_repository_impl.dart';
import '../data/repositories/weight_log_repository_impl.dart';
import '../data/repositories/weight_repository_impl.dart';
import '../data/repositories/workout_category_repository_impl.dart';
import '../data/repositories/workout_exercise_repository_impl.dart';
import '../data/repositories/workout_history_repository_impl.dart';
import '../data/repositories/nutrition_repository_impl.dart';
import '../data/repositories/workout_library_repository_impl.dart';
import '../data/repositories/workout_repository_impl.dart';
import '../data/repositories/workout_session_repository_impl.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/backup_repository_impl.dart';
import '../data/services/auth/auth_service.dart';
import '../data/services/auth/google_sign_in_service.dart';
import '../data/services/backup/backup_encryption_service.dart';
import '../data/services/backup/backup_packaging_service.dart';
import '../data/services/backup/backup_service.dart';
import '../data/services/backup/google_drive_backup_service.dart';
import '../data/services/firebase_service.dart';
import '../data/services/notifications/local_notification_service.dart';
import '../data/services/report/report_exporter.dart';
import '../data/services/security/app_error_logger.dart';
import '../data/services/security/app_security_service.dart';
import '../data/services/security/key_manager.dart';
import '../data/services/security/recovery_manager.dart';
import '../data/services/security/session_manager.dart';
import '../data/services/storage/database_optimizer_service.dart';
import '../data/services/storage/profile_photo_service.dart';
import '../data/services/storage/secure_storage_service.dart';
import '../data/services/storage/settings_storage_service.dart';
import '../data/services/sync/sync_engine.dart';
import '../data/services/food_seeder.dart';
import '../data/services/workout_seeder.dart';
import '../domain/repositories/app_preferences_repository.dart';
import '../domain/repositories/app_settings_repository.dart';
import '../domain/repositories/achievement_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/challenge_repository.dart';
import '../domain/repositories/dashboard_repository.dart';
import '../domain/repositories/global_search_repository.dart';
import '../domain/repositories/backup_history_repository.dart';
import '../domain/repositories/nutrition_repository.dart';
import '../domain/repositories/backup_repository.dart';
import '../domain/repositories/badge_repository.dart';
import '../domain/repositories/bmi_log_repository.dart';
import '../domain/repositories/body_measurement_repository.dart';
import '../domain/repositories/daily_progress_repository.dart';
import '../domain/repositories/exercise_history_repository.dart';
import '../domain/repositories/exercise_repository.dart';
import '../domain/repositories/fitness_goal_repository.dart';
import '../domain/repositories/food_item_repository.dart';
import '../domain/repositories/food_log_repository.dart';
import '../domain/repositories/hydration_repository.dart';
import '../domain/repositories/level_repository.dart';
import '../domain/repositories/meal_category_repository.dart';
import '../domain/repositories/meal_item_repository.dart';
import '../domain/repositories/meal_repository.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/repositories/progress_analytics_repository.dart';
import '../domain/repositories/reminder_history_repository.dart';
import '../domain/repositories/reminder_repository.dart';
import '../domain/repositories/reward_repository.dart';
import '../domain/repositories/session_repository.dart';
import '../domain/repositories/sleep_log_repository.dart';
import '../domain/repositories/smart_reminder_repository.dart';
import '../domain/repositories/step_log_repository.dart';
import '../domain/repositories/streak_repository.dart';
import '../domain/repositories/sync_event_repository.dart';
import '../domain/repositories/user_fitness_profile_repository.dart';
import '../domain/repositories/xp_history_repository.dart';
import '../domain/repositories/user_profile_repository.dart';
import '../domain/repositories/water_log_repository.dart';
import '../domain/repositories/weight_log_repository.dart';
import '../domain/repositories/weight_repository.dart';
import '../domain/repositories/workout_category_repository.dart';
import '../domain/repositories/workout_exercise_repository.dart';
import '../domain/repositories/workout_history_repository.dart';
import '../domain/repositories/workout_library_repository.dart';
import '../domain/repositories/workout_repository.dart';
import '../domain/repositories/workout_session_repository.dart';
import '../domain/repositories/error_log_repository.dart';
import '../domain/usecases/auth/reload_user_usecase.dart';
import '../domain/usecases/auth/delete_account_usecase.dart';
import '../domain/usecases/auth/reset_password_usecase.dart';
import '../domain/usecases/auth/send_email_verification_usecase.dart';
import '../domain/usecases/auth/sign_in_with_email_usecase.dart';
import '../domain/usecases/auth/sign_in_with_google_usecase.dart';
import '../domain/usecases/auth/sign_out_usecase.dart';
import '../domain/usecases/auth/sign_up_with_email_usecase.dart';

/// Composition root.
///
/// Override [sharedPreferencesProvider] during bootstrap with the preloaded
/// [SharedPreferences] instance so preference reads are synchronous.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('SharedPreferences must be overridden'),
);

final networkInfoProvider = Provider<NetworkInfo>(
  (ref) => NetworkInfo(),
);

final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

final profilePhotoServiceProvider = Provider<ProfilePhotoService>(
  (ref) => ProfilePhotoService(),
);

final firebaseServiceProvider = Provider<FirebaseService>(
  (ref) => FirebaseService(),
);

final googleSignInServiceProvider = Provider<GoogleSignInService>(
  (ref) => GoogleSignInService(),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    firebaseService: ref.watch(firebaseServiceProvider),
    googleSignInService: ref.watch(googleSignInServiceProvider),
  ),
);

final googleDriveBackupServiceProvider = Provider<GoogleDriveBackupService>(
  (ref) => GoogleDriveBackupService(
    signInService: ref.watch(googleSignInServiceProvider),
  ),
);

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => AppDatabase(),
);

final localNotificationServiceProvider = Provider<LocalNotificationService>(
  (ref) => LocalNotificationService.instance,
);

final reportExporterProvider = Provider<ReportExporter>(
  (ref) => ReportExporter(),
);

final settingsStorageServiceProvider = Provider<SettingsStorageService>(
  (ref) => SettingsStorageService(database: ref.watch(appDatabaseProvider)),
);

final appSecurityServiceProvider = Provider<AppSecurityService>(
  (ref) => AppSecurityService(),
);

final userLocalDataSourceProvider = Provider<UserLocalDataSource>(
  (ref) => UserLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepositoryImpl(ref.watch(userLocalDataSourceProvider)),
);

final userProfileLocalDataSourceProvider = Provider<UserProfileLocalDataSource>(
  (ref) =>
      UserProfileLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final fitnessGoalLocalDataSourceProvider = Provider<FitnessGoalLocalDataSource>(
  (ref) =>
      FitnessGoalLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final workoutCategoryLocalDataSourceProvider =
    Provider<WorkoutCategoryLocalDataSource>(
      (ref) =>
          WorkoutCategoryLocalDataSource(database: ref.watch(appDatabaseProvider)),
    );

final workoutLocalDataSourceProvider = Provider<WorkoutLocalDataSource>(
  (ref) => WorkoutLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final exerciseLocalDataSourceProvider = Provider<ExerciseLocalDataSource>(
  (ref) => ExerciseLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final workoutExerciseLocalDataSourceProvider =
    Provider<WorkoutExerciseLocalDataSource>(
      (ref) => WorkoutExerciseLocalDataSource(
        database: ref.watch(appDatabaseProvider),
      ),
    );

final workoutHistoryLocalDataSourceProvider =
    Provider<WorkoutHistoryLocalDataSource>(
      (ref) => WorkoutHistoryLocalDataSource(
        database: ref.watch(appDatabaseProvider),
      ),
    );

final exerciseHistoryLocalDataSourceProvider =
    Provider<ExerciseHistoryLocalDataSource>(
      (ref) => ExerciseHistoryLocalDataSource(
        database: ref.watch(appDatabaseProvider),
      ),
    );

final mealCategoryLocalDataSourceProvider =
    Provider<MealCategoryLocalDataSource>(
      (ref) =>
          MealCategoryLocalDataSource(database: ref.watch(appDatabaseProvider)),
    );

final mealLocalDataSourceProvider = Provider<MealLocalDataSource>(
  (ref) => MealLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final foodItemLocalDataSourceProvider = Provider<FoodItemLocalDataSource>(
  (ref) => FoodItemLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final foodLogLocalDataSourceProvider = Provider<FoodLogLocalDataSource>(
  (ref) => FoodLogLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final waterLogLocalDataSourceProvider = Provider<WaterLogLocalDataSource>(
  (ref) => WaterLogLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final weightLogLocalDataSourceProvider = Provider<WeightLogLocalDataSource>(
  (ref) => WeightLogLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final bmiLogLocalDataSourceProvider = Provider<BmiLogLocalDataSource>(
  (ref) => BmiLogLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final bodyMeasurementLocalDataSourceProvider =
    Provider<BodyMeasurementLocalDataSource>(
      (ref) => BodyMeasurementLocalDataSource(
        database: ref.watch(appDatabaseProvider),
      ),
    );

final sleepLogLocalDataSourceProvider = Provider<SleepLogLocalDataSource>(
  (ref) => SleepLogLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final stepLogLocalDataSourceProvider = Provider<StepLogLocalDataSource>(
  (ref) => StepLogLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final reminderLocalDataSourceProvider = Provider<ReminderLocalDataSource>(
  (ref) => ReminderLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final achievementLocalDataSourceProvider = Provider<AchievementLocalDataSource>(
  (ref) => AchievementLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final badgeLocalDataSourceProvider = Provider<BadgeLocalDataSource>(
  (ref) => BadgeLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final xpHistoryLocalDataSourceProvider = Provider<XpHistoryLocalDataSource>(
  (ref) => XpHistoryLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final levelLocalDataSourceProvider = Provider<LevelLocalDataSource>(
  (ref) => LevelLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final challengeLocalDataSourceProvider = Provider<ChallengeLocalDataSource>(
  (ref) => ChallengeLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final rewardLocalDataSourceProvider = Provider<RewardLocalDataSource>(
  (ref) => RewardLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final streakLocalDataSourceProvider = Provider<StreakLocalDataSource>(
  (ref) => StreakLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final dailyProgressLocalDataSourceProvider =
    Provider<DailyProgressLocalDataSource>(
      (ref) => DailyProgressLocalDataSource(
        database: ref.watch(appDatabaseProvider),
      ),
    );

final appSettingsLocalDataSourceProvider = Provider<AppSettingsLocalDataSource>(
  (ref) => AppSettingsLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final backupHistoryLocalDataSourceProvider =
    Provider<BackupHistoryLocalDataSource>(
      (ref) => BackupHistoryLocalDataSource(
        database: ref.watch(appDatabaseProvider),
      ),
    );

final userFitnessProfileRepositoryProvider =
    Provider<UserFitnessProfileRepository>(
      (ref) => UserFitnessProfileRepositoryImpl(
        ref.watch(userProfileLocalDataSourceProvider),
      ),
    );

final fitnessGoalRepositoryProvider = Provider<FitnessGoalRepository>(
  (ref) => FitnessGoalRepositoryImpl(
    ref.watch(fitnessGoalLocalDataSourceProvider),
  ),
);

final workoutCategoryRepositoryProvider = Provider<WorkoutCategoryRepository>(
  (ref) => WorkoutCategoryRepositoryImpl(
    ref.watch(workoutCategoryLocalDataSourceProvider),
  ),
);

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => WorkoutRepositoryImpl(ref.watch(workoutLocalDataSourceProvider)),
);

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepositoryImpl(ref.watch(exerciseLocalDataSourceProvider)),
);

final workoutExerciseRepositoryProvider = Provider<WorkoutExerciseRepository>(
  (ref) => WorkoutExerciseRepositoryImpl(
    ref.watch(workoutExerciseLocalDataSourceProvider),
  ),
);

final workoutHistoryRepositoryProvider = Provider<WorkoutHistoryRepository>(
  (ref) => WorkoutHistoryRepositoryImpl(
    ref.watch(workoutHistoryLocalDataSourceProvider),
  ),
);

final exerciseHistoryRepositoryProvider = Provider<ExerciseHistoryRepository>(
  (ref) => ExerciseHistoryRepositoryImpl(
    ref.watch(exerciseHistoryLocalDataSourceProvider),
  ),
);

final mealCategoryRepositoryProvider = Provider<MealCategoryRepository>(
  (ref) => MealCategoryRepositoryImpl(
    ref.watch(mealCategoryLocalDataSourceProvider),
  ),
);

final mealRepositoryProvider = Provider<MealRepository>(
  (ref) => MealRepositoryImpl(ref.watch(mealLocalDataSourceProvider)),
);

final foodItemRepositoryProvider = Provider<FoodItemRepository>(
  (ref) => FoodItemRepositoryImpl(ref.watch(foodItemLocalDataSourceProvider)),
);

final foodLogRepositoryProvider = Provider<FoodLogRepository>(
  (ref) => FoodLogRepositoryImpl(ref.watch(foodLogLocalDataSourceProvider)),
);

final mealItemLocalDataSourceProvider = Provider<MealItemLocalDataSource>(
  (ref) => MealItemLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final mealItemRepositoryProvider = Provider<MealItemRepository>(
  (ref) => MealItemRepositoryImpl(ref.watch(mealItemLocalDataSourceProvider)),
);

final foodSeederProvider = Provider<FoodSeeder>(
  (ref) => FoodSeeder(database: ref.watch(appDatabaseProvider)),
);

final nutritionRepositoryProvider = Provider<NutritionRepository>(
  (ref) => NutritionRepositoryImpl(
    foodItemRepository: ref.watch(foodItemRepositoryProvider),
    foodLogRepository: ref.watch(foodLogRepositoryProvider),
    mealCategoryRepository: ref.watch(mealCategoryRepositoryProvider),
    mealRepository: ref.watch(mealRepositoryProvider),
    mealItemRepository: ref.watch(mealItemRepositoryProvider),
    waterLogRepository: ref.watch(waterLogRepositoryProvider),
    userProfileRepository: ref.watch(userFitnessProfileRepositoryProvider),
    foodSeeder: ref.watch(foodSeederProvider),
  ),
);

final waterLogRepositoryProvider = Provider<WaterLogRepository>(
  (ref) => WaterLogRepositoryImpl(ref.watch(waterLogLocalDataSourceProvider)),
);

final hydrationRepositoryProvider = Provider<HydrationRepository>(
  (ref) => HydrationRepositoryImpl(
    waterLogRepository: ref.watch(waterLogRepositoryProvider),
    userProfileRepository: ref.watch(userFitnessProfileRepositoryProvider),
    reminderRepository: ref.watch(reminderRepositoryProvider),
    notificationService: ref.watch(localNotificationServiceProvider),
  ),
);

final weightLogRepositoryProvider = Provider<WeightLogRepository>(
  (ref) => WeightLogRepositoryImpl(ref.watch(weightLogLocalDataSourceProvider)),
);

final bmiLogRepositoryProvider = Provider<BmiLogRepository>(
  (ref) => BmiLogRepositoryImpl(ref.watch(bmiLogLocalDataSourceProvider)),
);

final bodyMeasurementRepositoryProvider = Provider<BodyMeasurementRepository>(
  (ref) => BodyMeasurementRepositoryImpl(
    ref.watch(bodyMeasurementLocalDataSourceProvider),
  ),
);

final weightRepositoryProvider = Provider<WeightRepository>(
  (ref) => WeightRepositoryImpl(
    weightLogRepository: ref.watch(weightLogRepositoryProvider),
    bmiLogRepository: ref.watch(bmiLogRepositoryProvider),
    bodyMeasurementRepository: ref.watch(bodyMeasurementRepositoryProvider),
    userProfileRepository: ref.watch(userFitnessProfileRepositoryProvider),
  ),
);

final sleepLogRepositoryProvider = Provider<SleepLogRepository>(
  (ref) => SleepLogRepositoryImpl(ref.watch(sleepLogLocalDataSourceProvider)),
);

final stepLogRepositoryProvider = Provider<StepLogRepository>(
  (ref) => StepLogRepositoryImpl(ref.watch(stepLogLocalDataSourceProvider)),
);

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => ReminderRepositoryImpl(ref.watch(reminderLocalDataSourceProvider)),
);

final reminderHistoryLocalDataSourceProvider =
    Provider<ReminderHistoryLocalDataSource>(
      (ref) => ReminderHistoryLocalDataSource(
        database: ref.watch(appDatabaseProvider),
      ),
    );

final reminderHistoryRepositoryProvider = Provider<ReminderHistoryRepository>(
  (ref) => ReminderHistoryRepositoryImpl(
    dataSource: ref.watch(reminderHistoryLocalDataSourceProvider),
    reminderRepository: ref.watch(reminderRepositoryProvider),
  ),
);

final smartReminderRepositoryProvider = Provider<SmartReminderRepository>(
  (ref) => SmartReminderRepositoryImpl(
    workoutHistoryRepository: ref.watch(workoutHistoryRepositoryProvider),
    waterLogRepository: ref.watch(waterLogRepositoryProvider),
    weightLogRepository: ref.watch(weightLogRepositoryProvider),
    hydrationRepository: ref.watch(hydrationRepositoryProvider),
  ),
);

final achievementRepositoryProvider = Provider<AchievementRepository>(
  (ref) => AchievementRepositoryImpl(
    ref.watch(achievementLocalDataSourceProvider),
  ),
);

final badgeRepositoryProvider = Provider<BadgeRepository>(
  (ref) => BadgeRepositoryImpl(ref.watch(badgeLocalDataSourceProvider)),
);

final xpHistoryRepositoryProvider = Provider<XpHistoryRepository>(
  (ref) => XpHistoryRepositoryImpl(ref.watch(xpHistoryLocalDataSourceProvider)),
);

final levelRepositoryProvider = Provider<LevelRepository>(
  (ref) => LevelRepositoryImpl(ref.watch(levelLocalDataSourceProvider)),
);

final challengeRepositoryProvider = Provider<ChallengeRepository>(
  (ref) => ChallengeRepositoryImpl(ref.watch(challengeLocalDataSourceProvider)),
);

final rewardRepositoryProvider = Provider<RewardRepository>(
  (ref) => RewardRepositoryImpl(ref.watch(rewardLocalDataSourceProvider)),
);

final streakRepositoryProvider = Provider<StreakRepository>(
  (ref) => StreakRepositoryImpl(ref.watch(streakLocalDataSourceProvider)),
);

final dailyProgressRepositoryProvider = Provider<DailyProgressRepository>(
  (ref) => DailyProgressRepositoryImpl(
    ref.watch(dailyProgressLocalDataSourceProvider),
  ),
);

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>(
  (ref) => AppSettingsRepositoryImpl(
    ref.watch(appSettingsLocalDataSourceProvider),
  ),
);

final backupHistoryRepositoryProvider = Provider<BackupHistoryRepository>(
  (ref) => BackupHistoryRepositoryImpl(
    ref.watch(backupHistoryLocalDataSourceProvider),
  ),
);

final appPreferencesRepositoryProvider =
    Provider<AppPreferencesRepository>(
  (ref) => AppPreferencesRepositoryImpl(
    preferences: ref.watch(sharedPreferencesProvider),
  ),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepositoryImpl(
    workoutHistoryRepository: ref.watch(workoutHistoryRepositoryProvider),
    waterLogRepository: ref.watch(waterLogRepositoryProvider),
    stepLogRepository: ref.watch(stepLogRepositoryProvider),
    weightLogRepository: ref.watch(weightLogRepositoryProvider),
    bmiLogRepository: ref.watch(bmiLogRepositoryProvider),
    foodLogRepository: ref.watch(foodLogRepositoryProvider),
    sleepLogRepository: ref.watch(sleepLogRepositoryProvider),
    streakRepository: ref.watch(streakRepositoryProvider),
    badgeRepository: ref.watch(badgeRepositoryProvider),
    reminderRepository: ref.watch(reminderRepositoryProvider),
    userFitnessProfileRepository: ref.watch(
      userFitnessProfileRepositoryProvider,
    ),
  ),
);

final globalSearchRepositoryProvider = Provider<GlobalSearchRepository>(
  (ref) => GlobalSearchRepositoryImpl(
    workoutRepository: ref.watch(workoutRepositoryProvider),
    exerciseRepository: ref.watch(exerciseRepositoryProvider),
    foodItemRepository: ref.watch(foodItemRepositoryProvider),
    mealRepository: ref.watch(mealRepositoryProvider),
  ),
);

final workoutSeederProvider = Provider<WorkoutSeeder>(
  (ref) => WorkoutSeeder(
    database: ref.watch(appDatabaseProvider),
  ),
);

final workoutLibraryRepositoryProvider = Provider<WorkoutLibraryRepository>(
  (ref) => WorkoutLibraryRepositoryImpl(
    workoutRepository: ref.watch(workoutRepositoryProvider),
    categoryRepository: ref.watch(workoutCategoryRepositoryProvider),
    historyRepository: ref.watch(workoutHistoryRepositoryProvider),
    workoutExerciseRepository: ref.watch(workoutExerciseRepositoryProvider),
    exerciseHistoryRepository: ref.watch(exerciseHistoryRepositoryProvider),
    userProfileRepository: ref.watch(userFitnessProfileRepositoryProvider),
    seeder: ref.watch(workoutSeederProvider),
  ),
);

final workoutSessionRepositoryProvider = Provider<WorkoutSessionRepository>(
  (ref) => WorkoutSessionRepositoryImpl(
    workoutHistoryRepository: ref.watch(workoutHistoryRepositoryProvider),
    exerciseHistoryRepository: ref.watch(exerciseHistoryRepositoryProvider),
    dailyProgressRepository: ref.watch(dailyProgressRepositoryProvider),
    streakRepository: ref.watch(streakRepositoryProvider),
    achievementRepository: ref.watch(achievementRepositoryProvider),
    badgeRepository: ref.watch(badgeRepositoryProvider),
    workoutRepository: ref.watch(workoutRepositoryProvider),
  ),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(
    userDataSource: ref.watch(userLocalDataSourceProvider),
    profileDataSource: ref.watch(userProfileLocalDataSourceProvider),
    workoutHistoryRepository: ref.watch(workoutHistoryRepositoryProvider),
    streakRepository: ref.watch(streakRepositoryProvider),
    waterLogRepository: ref.watch(waterLogRepositoryProvider),
    weightLogRepository: ref.watch(weightLogRepositoryProvider),
    stepLogRepository: ref.watch(stepLogRepositoryProvider),
  ),
);

final progressAnalyticsRepositoryProvider =
    Provider<ProgressAnalyticsRepository>(
      (ref) => ProgressAnalyticsRepositoryImpl(
        workoutHistoryRepository: ref.watch(workoutHistoryRepositoryProvider),
        waterLogRepository: ref.watch(waterLogRepositoryProvider),
        foodLogRepository: ref.watch(foodLogRepositoryProvider),
        weightLogRepository: ref.watch(weightLogRepositoryProvider),
        bmiLogRepository: ref.watch(bmiLogRepositoryProvider),
        sleepLogRepository: ref.watch(sleepLogRepositoryProvider),
        stepLogRepository: ref.watch(stepLogRepositoryProvider),
        streakRepository: ref.watch(streakRepositoryProvider),
        fitnessGoalRepository: ref.watch(fitnessGoalRepositoryProvider),
        userFitnessProfileRepository: ref.watch(
          userFitnessProfileRepositoryProvider,
        ),
      ),
    );

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(authServiceProvider),
    ref.watch(userProfileRepositoryProvider),
    ref.watch(secureStorageServiceProvider),
  ),
);

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepositoryImpl(
    backupService: ref.watch(googleDriveBackupServiceProvider),
  ),
);

final backupEncryptionServiceProvider = Provider<BackupEncryptionService>(
  (ref) => BackupEncryptionService(
    storage: ref.watch(secureStorageServiceProvider),
  ),
);

final backupPackagingServiceProvider = Provider<BackupPackagingService>(
  (ref) => BackupPackagingService(
    encryption: ref.watch(backupEncryptionServiceProvider),
  ),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    repository: ref.watch(backupRepositoryProvider),
    historyRepository: ref.watch(backupHistoryRepositoryProvider),
    settingsRepository: ref.watch(appSettingsRepositoryProvider),
    database: ref.watch(appDatabaseProvider),
    storageService: ref.watch(settingsStorageServiceProvider),
    encryption: ref.watch(backupEncryptionServiceProvider),
    packaging: ref.watch(backupPackagingServiceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  ),
);

final signInWithEmailUsecaseProvider = Provider<SignInWithEmailUsecase>(
  (ref) => SignInWithEmailUsecase(ref.watch(authRepositoryProvider)),
);

final signUpWithEmailUsecaseProvider = Provider<SignUpWithEmailUsecase>(
  (ref) => SignUpWithEmailUsecase(ref.watch(authRepositoryProvider)),
);

final signInWithGoogleUsecaseProvider = Provider<SignInWithGoogleUsecase>(
  (ref) => SignInWithGoogleUsecase(ref.watch(authRepositoryProvider)),
);

final signOutUsecaseProvider = Provider<SignOutUsecase>(
  (ref) => SignOutUsecase(ref.watch(authRepositoryProvider)),
);

final sendEmailVerificationUsecaseProvider =
    Provider<SendEmailVerificationUsecase>(
      (ref) => SendEmailVerificationUsecase(ref.watch(authRepositoryProvider)),
    );

final reloadUserUsecaseProvider = Provider<ReloadUserUsecase>(
  (ref) => ReloadUserUsecase(ref.watch(authRepositoryProvider)),
);

final resetPasswordUsecaseProvider = Provider<ResetPasswordUsecase>(
  (ref) => ResetPasswordUsecase(ref.watch(authRepositoryProvider)),
);

final deleteAccountUsecaseProvider = Provider<DeleteAccountUsecase>(
  (ref) => DeleteAccountUsecase(ref.watch(authRepositoryProvider)),
);

// ---------------------------------------------------------------------
// Security, encryption & offline sync
// ---------------------------------------------------------------------

final keyManagerProvider = Provider<KeyManager>(
  (ref) => KeyManager(storage: ref.watch(secureStorageServiceProvider)),
);

final sessionLocalDataSourceProvider = Provider<SessionLocalDataSource>(
  (ref) => SessionLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final syncEventLocalDataSourceProvider = Provider<SyncEventLocalDataSource>(
  (ref) => SyncEventLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final errorLogLocalDataSourceProvider = Provider<ErrorLogLocalDataSource>(
  (ref) => ErrorLogLocalDataSource(database: ref.watch(appDatabaseProvider)),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepositoryImpl(ref.watch(sessionLocalDataSourceProvider)),
);

final syncEventRepositoryProvider = Provider<SyncEventRepository>(
  (ref) => SyncEventRepositoryImpl(ref.watch(syncEventLocalDataSourceProvider)),
);

final errorLogRepositoryProvider = Provider<ErrorLogRepository>(
  (ref) => ErrorLogRepositoryImpl(ref.watch(errorLogLocalDataSourceProvider)),
);

final sessionManagerProvider = Provider<SessionManager>(
  (ref) => SessionManager(
    repository: ref.watch(sessionRepositoryProvider),
    storage: ref.watch(secureStorageServiceProvider),
  ),
);

final syncEngineProvider = Provider<SyncEngine>(
  (ref) => SyncEngine(repository: ref.watch(syncEventRepositoryProvider)),
);

final errorLoggerProvider = Provider<AppErrorLogger>(
  (ref) => AppErrorLogger(repository: ref.watch(errorLogRepositoryProvider)),
);

final databaseOptimizerServiceProvider = Provider<DatabaseOptimizerService>(
  (ref) => DatabaseOptimizerService(
    database: ref.watch(appDatabaseProvider),
    storageService: ref.watch(settingsStorageServiceProvider),
    syncEventRepository: ref.watch(syncEventRepositoryProvider),
    errorLogRepository: ref.watch(errorLogRepositoryProvider),
    sessionRepository: ref.watch(sessionRepositoryProvider),
  ),
);

final recoveryManagerProvider = Provider<RecoveryManager>(
  (ref) => RecoveryManager(
    database: ref.watch(appDatabaseProvider),
    backupService: ref.watch(backupServiceProvider),
    errorLogger: ref.watch(errorLoggerProvider),
  ),
);
