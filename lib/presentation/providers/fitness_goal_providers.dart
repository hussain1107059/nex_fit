import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/common_enums.dart';
import '../../domain/entities/fitness_goal.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';
import 'dashboard_providers.dart';
import 'progress_providers.dart';

/// The user's own goals, newest activity first.
final userGoalsProvider = FutureProvider.autoDispose<List<FitnessGoal>>((
  ref,
) async {
  final AppUser? user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return const <FitnessGoal>[];
  return ref.read(fitnessGoalRepositoryProvider).getByUserId(user.id);
});

/// Server-authoritative goal templates (master data, user_id IS NULL).
final goalTemplatesProvider = FutureProvider.autoDispose<List<FitnessGoal>>((
  ref,
) async {
  return ref.read(fitnessGoalRepositoryProvider).getTemplates();
});

/// Creates a user-owned goal from a template. The template itself is master
/// data and is never mutated; only the copy is written locally and synced.
Future<void> createGoalFromTemplate(
  WidgetRef ref,
  FitnessGoal template,
) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  final DateTime now = DateTime.now();
  await ref.read(fitnessGoalRepositoryProvider).insert(
    FitnessGoal(
      userId: user.id,
      title: template.title,
      description: template.description,
      goalType: template.goalType,
      targetValue: template.targetValue,
      startDate: now,
      createdAt: now,
      updatedAt: now,
    ),
  );
  _refreshGoalDependents(ref);
}

/// Creates a custom user goal.
Future<void> createUserGoal(
  WidgetRef ref, {
  required GoalType goalType,
  required String title,
  double? targetValue,
  DateTime? targetDate,
}) async {
  final AppUser? user = ref.read(currentUserProvider);
  if (user == null || !user.isSignedIn) return;
  final DateTime now = DateTime.now();
  await ref.read(fitnessGoalRepositoryProvider).insert(
    FitnessGoal(
      userId: user.id,
      title: title,
      goalType: goalType,
      targetValue: targetValue,
      targetDate: targetDate,
      startDate: now,
      createdAt: now,
      updatedAt: now,
    ),
  );
  _refreshGoalDependents(ref);
}

/// Saves edits to an existing user goal (target value, deadline, status).
Future<void> updateUserGoal(WidgetRef ref, FitnessGoal goal) async {
  await ref
      .read(fitnessGoalRepositoryProvider)
      .update(goal.copyWith(updatedAt: DateTime.now()));
  _refreshGoalDependents(ref);
}

/// Marks a goal as completed.
Future<void> completeUserGoal(WidgetRef ref, FitnessGoal goal) async {
  await updateUserGoal(
    ref,
    goal.copyWith(status: GoalStatus.completed),
  );
}

/// Deletes a user goal (soft delete, recorded as a DELETE sync event).
Future<void> deleteUserGoal(WidgetRef ref, int id) async {
  await ref.read(fitnessGoalRepositoryProvider).delete(id);
  _refreshGoalDependents(ref);
}

void _refreshGoalDependents(WidgetRef ref) {
  ref.invalidate(userGoalsProvider);
  ref.invalidate(goalProgressProvider);
  ref.invalidate(dashboardControllerProvider);
}