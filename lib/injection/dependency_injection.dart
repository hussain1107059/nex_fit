import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/network_info.dart';
import '../data/datasources/local/app_database.dart';
import '../data/datasources/local/app_settings_local_data_source.dart';
import '../data/datasources/local/achievement_local_data_source.dart';
import '../data/datasources/local/backup_history_local_data_source.dart';
import '../data/datasources/local/badge_local_data_source.dart';
import '../data/datasources/local/bmi_log_local_data_source.dart';
import '../data/datasources/local/body_measurement_local_data_source.dart';
import '../data/datasources/local/calorie_log_local_data_source.dart';
import '../data/datasources/local/daily_progress_local_data_source.dart';
import '../data/datasources/local/exercise_history_local_data_source.dart';
import '../data/datasources/local/exercise_local_data_source.dart';
import '../data/datasources/local/fitness_goal_local_data_source.dart';
import '../data/datasources/local/food_item_local_data_source.dart';
import '../data/datasources/local/food_log_local_data_source.dart';
import '../data/datasources/local/meal_category_local_data_source.dart';
import '../data/datasources/local/meal_item_local_data_source.dart';
import '../data/datasources/local/meal_local_data_source.dart';
import '../data/datasources/local/reminder_local_data_source.dart';
import '../data/datasources/local/sleep_log_local_data_source.dart';
import '../data/datasources/local/step_log_local_data_source.dart';
import '../data/datasources/local/streak_local_data_source.dart';
import '../data/datasources/local/user_local_data_source.dart';
import '../data/datasources/local/user_profile_local_data_source.dart';
import '../data/datasources/local/water_log_local_data_source.dart';
import '../data/datasources/local/weight_log_local_data_source.dart';
import '../data/datasources/local/workout_category_local_data_source.dart';
import '../data/datasources/local/workout_exercise_local_data_source.dart';
import '../data/datasources/local/workout_history_local_data_source.dart';
import '../data/datasources/local/workout_local_data_source.dart';
import '../data/repositories/app_preferences_repository_impl.dart';
import '../data/repositories/app_settings_repository_impl.dart';
import '../data/repositories/dashboard_repository_impl.dart';
import '../data/repositories/global_search_repository_impl.dart';
import '../data/repositories/profile_repository_impl.dart';
import '../data/repositories/achievement_repository_impl.dart';
import '../data/repositories/backup_history_repository_impl.dart';
import '../data/repositories/badge_repository_impl.dart';
import '../data/repositories/bmi_log_repository_impl.dart';
import '../data/repositories/body_measurement_repository_impl.dart';
import '../data/repositories/calorie_log_repository_impl.dart';
import '../data/repositories/daily_progress_repository_impl.dart';
import '../data/repositories/exercise_history_repository_impl.dart';
import '../data/repositories/exercise_repository_impl.dart';
import '../data/repositories/fitness_goal_repository_impl.dart';
import '../data/repositories/food_item_repository_impl.dart';
import '../data/repositories/food_log_repository_impl.dart';
import '../data/repositories/hydration_repository_impl.dart';
import '../data/repositories/meal_category_repository_impl.dart';
import '../data/repositories/meal_item_repository_impl.dart';
import '../data/repositories/meal_repository_impl.dart';
import '../data/repositories/reminder_repository_impl.dart';
import '../data/repositories/sleep_log_repository_impl.dart';
import '../data/repositories/step_log_repository_impl.dart';
import '../data/repositories/streak_repository_impl.dart';
import '../data/repositories/user_fitness_profile_repository_impl.dart';
import '../data/repositories/user_profile_repository_impl.dart';
import '../data/repositories/water_log_repository_impl.dart';
import '../data/repositories/weight_log_repository_impl.dart';
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
import '../data/services/backup/google_drive_backup_service.dart';
import '../data/services/firebase_service.dart';
import '../data/services/notifications/local_notification_service.dart';
import '../data/services/storage/profile_photo_service.dart';
import '../data/services/storage/secure_storage_service.dart';
import '../data/services/food_seeder.dart';
import '../data/services/workout_seeder.dart';
import '../domain/repositories/app_preferences_repository.dart';
import '../domain/repositories/app_settings_repository.dart';
import '../domain/repositories/achievement_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/dashboard_repository.dart';
import '../domain/repositories/global_search_repository.dart';
import '../domain/repositories/backup_history_repository.dart';
import '../domain/repositories/nutrition_repository.dart';
import '../domain/repositories/backup_repository.dart';
import '../domain/repositories/badge_repository.dart';
import '../domain/repositories/bmi_log_repository.dart';
import '../domain/repositories/body_measurement_repository.dart';
import '../domain/repositories/calorie_log_repository.dart';
import '../domain/repositories/daily_progress_repository.dart';
import '../domain/repositories/exercise_history_repository.dart';
import '../domain/repositories/exercise_repository.dart';
import '../domain/repositories/fitness_goal_repository.dart';
import '../domain/repositories/food_item_repository.dart';
import '../domain/repositories/food_log_repository.dart';
import '../domain/repositories/hydration_repository.dart';
import '../domain/repositories/meal_category_repository.dart';
import '../domain/repositories/meal_item_repository.dart';
import '../domain/repositories/meal_repository.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/repositories/reminder_repository.dart';
import '../domain/repositories/sleep_log_repository.dart';
import '../domain/repositories/step_log_repository.dart';
import '../domain/repositories/streak_repository.dart';
import '../domain/repositories/user_fitness_profile_repository.dart';
import '../domain/repositories/user_profile_repository.dart';
import '../domain/repositories/water_log_repository.dart';
import '../domain/repositories/weight_log_repository.dart';
import '../domain/repositories/workout_category_repository.dart';
import '../domain/repositories/workout_exercise_repository.dart';
import '../domain/repositories/workout_history_repository.dart';
import '../domain/repositories/workout_library_repository.dart';
import '../domain/repositories/workout_repository.dart';
import '../domain/repositories/workout_session_repository.dart';
import '../domain/usecases/auth/reload_user_usecase.dart';
import '../domain/usecases/auth/reset_password_usecase.dart';
import '../domain/usecases/auth/send_email_verification_usecase.dart';
import '../domain/usecases/auth/sign_in_with_email_usecase.dart';
import '../domain/usecases/auth/sign_in_with_google_usecase.dart';
import '../domain/usecases/auth/sign_out_usecase.dart';
import '../domain/usecases/auth/sign_up_with_email_usecase.dart';
import '../domain/usecases/auth/watch_auth_state_usecase.dart';

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

final calorieLogLocalDataSourceProvider = Provider<CalorieLogLocalDataSource>(
  (ref) => CalorieLogLocalDataSource(database: ref.watch(appDatabaseProvider)),
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

final calorieLogRepositoryProvider = Provider<CalorieLogRepository>(
  (ref) => CalorieLogRepositoryImpl(ref.watch(calorieLogLocalDataSourceProvider)),
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

final achievementRepositoryProvider = Provider<AchievementRepository>(
  (ref) => AchievementRepositoryImpl(
    ref.watch(achievementLocalDataSourceProvider),
  ),
);

final badgeRepositoryProvider = Provider<BadgeRepository>(
  (ref) => BadgeRepositoryImpl(ref.watch(badgeLocalDataSourceProvider)),
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

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(authServiceProvider),
    ref.watch(userProfileRepositoryProvider),
  ),
);

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepositoryImpl(
    backupService: ref.watch(googleDriveBackupServiceProvider),
    preferences: ref.watch(appPreferencesRepositoryProvider),
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

final watchAuthStateUsecaseProvider = Provider<WatchAuthStateUsecase>(
  (ref) => WatchAuthStateUsecase(ref.watch(authRepositoryProvider)),
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
