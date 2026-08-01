import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/reminder.dart';
import '../providers/auth_controller.dart';
import '../providers/exercise_providers.dart';
import '../providers/workout_providers.dart';
import '../screens/auth/email_verification_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/exercise/exercise_detail_screen.dart';
import '../screens/exercise/exercise_library_screen.dart';
import '../screens/exercise/exercise_player_screen.dart';
import '../screens/nutrition/food_database_screen.dart';
import '../screens/nutrition/food_detail_screen.dart';
import '../screens/nutrition/macro_tracker_screen.dart';
import '../screens/nutrition/meal_planner_screen.dart';
import '../screens/nutrition/nutrition_history_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/progress/fitness_score_screen.dart';
import '../screens/progress/goal_progress_screen.dart';
import '../screens/progress/personal_records_screen.dart';
import '../screens/progress/progress_dashboard_screen.dart';
import '../screens/progress/progress_report_screen.dart';
import '../screens/reminder/reminder_editor_screen.dart';
import '../screens/reminder/reminder_history_screen.dart';
import '../screens/reminder/reminder_list_screen.dart';
import '../screens/reminder/reminder_settings_screen.dart';
import '../screens/reminder/reminder_statistics_screen.dart';
import '../screens/shell/app_shell_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/water/water_history_screen.dart';
import '../screens/water/water_reminders_screen.dart';
import '../screens/water/water_screen.dart';
import '../screens/water/water_statistics_screen.dart';
import '../screens/weight/body_measurement_screen.dart';
import '../screens/weight/weight_history_screen.dart';
import '../screens/weight/weight_statistics_screen.dart';
import '../screens/workout/workout_detail_screen.dart';
import '../screens/workout/workout_history_screen.dart';
import '../screens/workout/workout_list_screen.dart';
import '../screens/workout/workout_player_screen.dart';

/// Route paths used across the app.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String emailVerification = '/email-verification';
  static const String shell = '/shell';
  static const String profileEdit = '/profile/edit';
  static const String workoutDetail = '/workout/detail/:workoutId';
  static const String workoutList = '/workout/list';
  static const String workoutHistory = '/workout/history';
  static const String workoutPlayer = '/workout/player';
  static const String exerciseList = '/exercise/list';
  static const String exerciseDetail = '/exercise/detail/:exerciseId';
  static const String exercisePlayer = '/exercise/player';
  static const String foodDatabase = '/nutrition/food-database';
  static const String foodDetail = '/nutrition/food/:foodId';
  static const String macroTracker = '/nutrition/macro-tracker';
  static const String nutritionHistory = '/nutrition/history';
  static const String mealPlanner = '/nutrition/meal-planner';
  static const String water = '/water';
  static const String waterHistory = '/water/history';
  static const String waterStatistics = '/water/statistics';
  static const String waterReminders = '/water/reminders';
  static const String weightHistory = '/weight/history';
  static const String weightStatistics = '/weight/statistics';
  static const String bodyMeasurement = '/weight/measurements';
  static const String progressDashboard = '/progress/dashboard';
  static const String progressReport = '/progress/report';
  static const String progressRecords = '/progress/records';
  static const String progressGoals = '/progress/goals';
  static const String progressScore = '/progress/score';
  static const String reminders = '/reminders';
  static const String reminderEditor = '/reminders/edit';
  static const String reminderHistory = '/reminders/history';
  static const String reminderStatistics = '/reminders/statistics';
  static const String reminderSettings = '/reminders/settings';

  /// The landing route for a freshly signed-in user.
  static String destinationFor(AppUser user) {
    return user.isEmailVerified ? shell : emailVerification;
  }

  /// Resolved detail route for [workoutId].
  static String workoutDetailPath(int workoutId) =>
      '/workout/detail/$workoutId';

  /// Resolved detail route for [exerciseId].
  static String exerciseDetailPath(int exerciseId) =>
      '/exercise/detail/$exerciseId';

  /// Resolved detail route for [foodId].
  static String foodDetailPath(int foodId) => '/nutrition/food/$foodId';
}

/// Central [GoRouter] configuration.
///
/// Auth state is watched via [authControllerProvider]; every change bumps a
/// [ChangeNotifier] so the redirect callback is re-evaluated.
final appRouterProvider = Provider<GoRouter>((ref) {
  final _AuthRefreshListenable refresh = _AuthRefreshListenable();
  ref.listen<AuthState>(
    authControllerProvider,
    (AuthState? previous, AuthState next) => refresh.bump(),
  );
  ref.onDispose(refresh.dispose);

  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      return _resolveRedirect(ref, state);
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (BuildContext context, GoRouterState state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (BuildContext context, GoRouterState state) =>
            const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgot-password',
        builder: (BuildContext context, GoRouterState state) =>
            const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailVerification,
        name: 'email-verification',
        builder: (BuildContext context, GoRouterState state) =>
            const EmailVerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.shell,
        name: 'shell',
        builder: (BuildContext context, GoRouterState state) =>
            const AppShellScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        name: 'profile-edit',
        builder: (BuildContext context, GoRouterState state) =>
            const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.workoutDetail,
        name: 'workout-detail',
        builder: (BuildContext context, GoRouterState state) =>
            WorkoutDetailScreen(
              workoutId: int.parse(state.pathParameters['workoutId']!),
            ),
      ),
      GoRoute(
        path: AppRoutes.workoutList,
        name: 'workout-list',
        builder: (BuildContext context, GoRouterState state) =>
            WorkoutListScreen(
              args:
                  state.extra as WorkoutListArgs? ??
                  const WorkoutListArgs.all(),
            ),
      ),
      GoRoute(
        path: AppRoutes.workoutHistory,
        name: 'workout-history',
        builder: (BuildContext context, GoRouterState state) =>
            const WorkoutHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.workoutPlayer,
        name: 'workout-player',
        builder: (BuildContext context, GoRouterState state) {
          final WorkoutPlayerArgs args = state.extra as WorkoutPlayerArgs;
          return WorkoutPlayerScreen(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.exerciseList,
        name: 'exercise-list',
        builder: (BuildContext context, GoRouterState state) =>
            const ExerciseLibraryScreen(),
      ),
      GoRoute(
        path: AppRoutes.exerciseDetail,
        name: 'exercise-detail',
        builder: (BuildContext context, GoRouterState state) =>
            ExerciseDetailScreen(
              exerciseId: int.parse(state.pathParameters['exerciseId']!),
            ),
      ),
      GoRoute(
        path: AppRoutes.exercisePlayer,
        name: 'exercise-player',
        builder: (BuildContext context, GoRouterState state) {
          final ExercisePlayerArgs args = state.extra as ExercisePlayerArgs;
          return ExercisePlayerScreen(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.foodDatabase,
        name: 'food-database',
        builder: (BuildContext context, GoRouterState state) {
          final FoodDatabaseArgs args =
              state.extra as FoodDatabaseArgs? ??
              const FoodDatabaseArgs();
          return FoodDatabaseScreen(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.foodDetail,
        name: 'food-detail',
        builder: (BuildContext context, GoRouterState state) =>
            FoodDetailScreen(
              foodId: int.parse(state.pathParameters['foodId']!),
            ),
      ),
      GoRoute(
        path: AppRoutes.macroTracker,
        name: 'macro-tracker',
        builder: (BuildContext context, GoRouterState state) =>
            const MacroTrackerScreen(),
      ),
      GoRoute(
        path: AppRoutes.nutritionHistory,
        name: 'nutrition-history',
        builder: (BuildContext context, GoRouterState state) =>
            const NutritionHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.mealPlanner,
        name: 'meal-planner',
        builder: (BuildContext context, GoRouterState state) =>
            const MealPlannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.water,
        name: 'water',
        builder: (BuildContext context, GoRouterState state) =>
            const WaterScreen(),
      ),
      GoRoute(
        path: AppRoutes.waterHistory,
        name: 'water-history',
        builder: (BuildContext context, GoRouterState state) =>
            const WaterHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.waterStatistics,
        name: 'water-statistics',
        builder: (BuildContext context, GoRouterState state) =>
            const WaterStatisticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.waterReminders,
        name: 'water-reminders',
        builder: (BuildContext context, GoRouterState state) =>
            const WaterRemindersScreen(),
      ),
      GoRoute(
        path: AppRoutes.weightHistory,
        name: 'weight-history',
        builder: (BuildContext context, GoRouterState state) =>
            const WeightHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.weightStatistics,
        name: 'weight-statistics',
        builder: (BuildContext context, GoRouterState state) =>
            const WeightStatisticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.bodyMeasurement,
        name: 'body-measurement',
        builder: (BuildContext context, GoRouterState state) =>
            const BodyMeasurementScreen(),
      ),
      GoRoute(
        path: AppRoutes.progressDashboard,
        name: 'progress-dashboard',
        builder: (BuildContext context, GoRouterState state) =>
            const ProgressDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.progressReport,
        name: 'progress-report',
        builder: (BuildContext context, GoRouterState state) =>
            const ProgressReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.progressRecords,
        name: 'progress-records',
        builder: (BuildContext context, GoRouterState state) =>
            const PersonalRecordsScreen(),
      ),
      GoRoute(
        path: AppRoutes.progressGoals,
        name: 'progress-goals',
        builder: (BuildContext context, GoRouterState state) =>
            const GoalProgressScreen(),
      ),
      GoRoute(
        path: AppRoutes.progressScore,
        name: 'progress-score',
        builder: (BuildContext context, GoRouterState state) =>
            const FitnessScoreScreen(),
      ),
      GoRoute(
        path: AppRoutes.reminders,
        name: 'reminders',
        builder: (BuildContext context, GoRouterState state) =>
            const ReminderListScreen(),
      ),
      GoRoute(
        path: AppRoutes.reminderEditor,
        name: 'reminder-editor',
        builder: (BuildContext context, GoRouterState state) =>
            ReminderEditorScreen(
              existing: state.extra as Reminder?,
            ),
      ),
      GoRoute(
        path: AppRoutes.reminderHistory,
        name: 'reminder-history',
        builder: (BuildContext context, GoRouterState state) =>
            const ReminderHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.reminderStatistics,
        name: 'reminder-statistics',
        builder: (BuildContext context, GoRouterState state) =>
            const ReminderStatisticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.reminderSettings,
        name: 'reminder-settings',
        builder: (BuildContext context, GoRouterState state) =>
            const ReminderSettingsScreen(),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) {
      return const _NotFoundScreen();
    },
  );

  ref.onDispose(router.dispose);
  return router;
});

/// Route guard that keeps unauthenticated users on the auth screens and
/// forces unverified users through the email verification screen.
String? _resolveRedirect(Ref ref, GoRouterState state) {
  final String path = state.matchedLocation;

  // The splash screen bootstraps services and performs the first navigation.
  if (path == AppRoutes.splash) return null;

  final AuthState auth = ref.read(authControllerProvider);
  final AppUser? user = auth.user;
  final bool signedIn = user != null && user.isSignedIn;

  final bool onPublic =
      path.startsWith(AppRoutes.login) ||
      path.startsWith(AppRoutes.register) ||
      path.startsWith(AppRoutes.forgotPassword);

  if (!signedIn) {
    return onPublic ? null : AppRoutes.login;
  }

  if (!user.isEmailVerified) {
    if (path.startsWith(AppRoutes.emailVerification)) return null;
    return AppRoutes.emailVerification;
  }

  if (onPublic || path.startsWith(AppRoutes.emailVerification)) {
    return AppRoutes.shell;
  }
  return null;
}

/// Bridges the auth controller state into [GoRouter]'s refresh mechanism.
class _AuthRefreshListenable extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// Fallback screen for unknown routes.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Text(
          'Route not found',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
