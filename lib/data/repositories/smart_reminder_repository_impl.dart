import '../../domain/entities/common_enums.dart';
import '../../domain/entities/smart_reminder_suggestion.dart';
import '../../domain/entities/water_log.dart';
import '../../domain/entities/weight_log.dart';
import '../../domain/entities/workout_history.dart';
import '../../domain/repositories/hydration_repository.dart';
import '../../domain/repositories/smart_reminder_repository.dart';
import '../../domain/repositories/water_log_repository.dart';
import '../../domain/repositories/weight_log_repository.dart';
import '../../domain/repositories/workout_history_repository.dart';

/// Smart reminder engine backed by the user's real progress records.
class SmartReminderRepositoryImpl implements SmartReminderRepository {
  SmartReminderRepositoryImpl({
    required this._workoutHistoryRepository,
    required this._waterLogRepository,
    required this._weightLogRepository,
    required this._hydrationRepository,
  });

  final WorkoutHistoryRepository _workoutHistoryRepository;
  final WaterLogRepository _waterLogRepository;
  final WeightLogRepository _weightLogRepository;
  final HydrationRepository _hydrationRepository;

  static const int _weightOverdueDays = 7;

  @override
  Future<List<SmartReminderSuggestion>> getSuggestions(String userId) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime tomorrow = today.add(const Duration(days: 1));

    final List<WorkoutHistory> todaysWorkouts =
        await _workoutHistoryRepository.getByDateRange(
          userId,
          today,
          tomorrow,
        );
    final bool workoutDone = todaysWorkouts.any(
      (WorkoutHistory w) => w.isCompleted,
    );

    final List<WaterLog> todaysWater = await _waterLogRepository.getByDateRange(
      userId,
      today,
      tomorrow,
    );
    final int intakeMl = todaysWater.fold(
      0,
      (int sum, WaterLog log) => sum + log.amountMl,
    );
    final int waterGoal = await _hydrationRepository.getGoal(userId);

    final WeightLog? latest = await _weightLogRepository.getLatest(userId);
    final bool weightOverdue =
        latest == null ||
        today.difference(DateTime(
              latest.loggedAt.year,
              latest.loggedAt.month,
              latest.loggedAt.day,
            )).inDays >= _weightOverdueDays;

    final List<SmartReminderSuggestion> suggestions = <SmartReminderSuggestion>[];
    if (!workoutDone) {
      suggestions.add(
        SmartReminderSuggestion(
          type: ReminderType.workout,
          title: 'Workout not completed yet',
          body: 'Add a quick workout reminder so you do not forget.',
          reason: 'No completed workout found for today.',
          relatedScreen: '/workout/list',
        ),
      );
    }
    if (intakeMl < waterGoal) {
      suggestions.add(
        SmartReminderSuggestion(
          type: ReminderType.water,
          title: 'Water goal not reached',
          body: 'You have logged ${intakeMl}ml of ${waterGoal}ml. Drink up!',
          reason: 'Current water intake is below the daily goal.',
          relatedScreen: '/water',
        ),
      );
    }
    if (weightOverdue) {
      suggestions.add(
        SmartReminderSuggestion(
          type: ReminderType.weight,
          title: 'Time to log your weight',
          body: 'Your last weight entry is more than a week old.',
          reason: 'Weight log is overdue.',
          relatedScreen: '/weight/history',
        ),
      );
    }
    return suggestions;
  }
}
