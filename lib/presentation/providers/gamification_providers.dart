import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/challenge.dart';
import '../../domain/entities/level.dart';
import '../../domain/entities/reward.dart';
import '../../domain/entities/xp_history.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';

final userLevelProvider = FutureProvider.autoDispose<LevelProgress?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return null;
  return ref.watch(levelRepositoryProvider).getByUserId(user.id);
});

final xpHistoryProvider = FutureProvider.autoDispose<List<XpHistory>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return const <XpHistory>[];
  return ref.watch(xpHistoryRepositoryProvider).getByUserId(user.id);
});

final activeChallengesProvider = FutureProvider.autoDispose<List<Challenge>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return const <Challenge>[];
  final data = await ref.watch(challengeRepositoryProvider).getByUserId(user.id);
  return data.where((challenge) => !challenge.isCompleted).toList();
});

final rewardsProvider = FutureProvider.autoDispose<List<Reward>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || !user.isSignedIn) return const <Reward>[];
  return ref.watch(rewardRepositoryProvider).getByUserId(user.id);
});
