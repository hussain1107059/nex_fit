import '../entities/achievement.dart';
import '../entities/badge.dart';
import '../entities/challenge.dart';
import '../entities/level.dart';
import '../entities/reward.dart';
import '../entities/xp_history.dart';
import '../repositories/achievement_repository.dart';
import '../repositories/badge_repository.dart';
import '../repositories/challenge_repository.dart';
import '../repositories/level_repository.dart';
import '../repositories/reward_repository.dart';
import '../repositories/xp_history_repository.dart';

class GamificationAwardResult {
  const GamificationAwardResult({
    required this.xpHistory,
    required this.level,
    required this.wasAwarded,
  });

  final XpHistory xpHistory;
  final LevelProgress level;
  final bool wasAwarded;
}

class GamificationService {
  const GamificationService({
    required XpHistoryRepository xpHistoryRepository,
    required LevelRepository levelRepository,
    required BadgeRepository badgeRepository,
    required AchievementRepository achievementRepository,
    required ChallengeRepository challengeRepository,
    required RewardRepository rewardRepository,
  }) : _xpHistoryRepository = xpHistoryRepository,
       _levelRepository = levelRepository,
       _badgeRepository = badgeRepository,
       _achievementRepository = achievementRepository,
       _challengeRepository = challengeRepository,
       _rewardRepository = rewardRepository;

  final XpHistoryRepository _xpHistoryRepository;
  final LevelRepository _levelRepository;
  final BadgeRepository _badgeRepository;
  final AchievementRepository _achievementRepository;
  final ChallengeRepository _challengeRepository;
  final RewardRepository _rewardRepository;

  static int _calculateRequiredXp(int level) => 100 + ((level - 1) * 75);

  static LevelProgress calculateLevelState({
    required String userId,
    required int totalXp,
    LevelProgress? current,
  }) {
    int levelCounter = current?.level ?? 1;
    int xpInCurrentLevel = current?.currentXp ?? 0;
    int requiredXp = _calculateRequiredXp(levelCounter);

    while (xpInCurrentLevel >= requiredXp) {
      xpInCurrentLevel -= requiredXp;
      levelCounter += 1;
      requiredXp = _calculateRequiredXp(levelCounter);
    }

    final int runningTotal = totalXp;
    if (runningTotal <= 0) {
      return LevelProgress(
        userId: userId,
        level: 1,
        currentXp: 0,
        requiredXp: _calculateRequiredXp(1),
        totalXp: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    int workingLevel = 1;
    int workingXp = runningTotal;
    while (workingXp >= _calculateRequiredXp(workingLevel)) {
      workingXp -= _calculateRequiredXp(workingLevel);
      workingLevel += 1;
    }

    return LevelProgress(
      userId: userId,
      level: workingLevel,
      currentXp: workingXp,
      requiredXp: _calculateRequiredXp(workingLevel),
      totalXp: runningTotal,
      createdAt: current?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<GamificationAwardResult> awardXp({
    required String userId,
    required int xp,
    required String source,
    required String reason,
    String? metadata,
  }) async {
    if (xp <= 0) {
      final total = await _xpHistoryRepository.totalXpForUser(userId);
      final current = await _levelRepository.getByUserId(userId) ??
          LevelProgress(
            userId: userId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
      return GamificationAwardResult(
        xpHistory: XpHistory(
          userId: userId,
          source: source,
          reason: reason,
          xp: 0,
          totalXp: total,
          metadata: metadata,
          createdAt: DateTime.now(),
        ),
        level: calculateLevelState(userId: userId, totalXp: total, current: current),
        wasAwarded: false,
      );
    }

    final duplicate = await _xpHistoryRepository.getByUserAndSourceAndReason(
      userId,
      source,
      reason,
    );
    if (duplicate != null) {
      final total = await _xpHistoryRepository.totalXpForUser(userId);
      final current = await _levelRepository.getByUserId(userId) ??
          LevelProgress(
            userId: userId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
      return GamificationAwardResult(
        xpHistory: duplicate,
        level: calculateLevelState(userId: userId, totalXp: total, current: current),
        wasAwarded: false,
      );
    }

    final total = await _xpHistoryRepository.totalXpForUser(userId) + xp;
    final current = await _levelRepository.getByUserId(userId);
    final nextLevel = calculateLevelState(
      userId: userId,
      totalXp: total,
      current: current,
    );

    final xpHistory = XpHistory(
      userId: userId,
      source: source,
      reason: reason,
      xp: xp,
      totalXp: total,
      metadata: metadata,
      createdAt: DateTime.now(),
    );

    await _xpHistoryRepository.insert(xpHistory);
    await _levelRepository.upsert(nextLevel);

    return GamificationAwardResult(
      xpHistory: xpHistory,
      level: nextLevel,
      wasAwarded: true,
    );
  }

  Future<Badge?> unlockBadge({
    required String userId,
    required String badgeType,
    required String badgeName,
    String? icon,
    int level = 1,
    double progress = 1,
    double target = 1,
  }) async {
    final existing = await _badgeRepository.getByUserAndType(userId, badgeType);
    if (existing != null && existing.isEarned) {
      return null;
    }

    final badge = Badge(
      userId: userId,
      badgeType: badgeType,
      badgeName: badgeName,
      icon: icon,
      level: level,
      progress: progress,
      target: target,
      isEarned: true,
      earnedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (existing == null) {
      await _badgeRepository.insert(badge);
      return badge;
    }

    final updated = existing.copyWith(
      badgeName: badgeName,
      icon: icon,
      level: level,
      progress: progress,
      target: target,
      isEarned: true,
      earnedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _badgeRepository.update(updated);
    return updated;
  }

  Future<Achievement?> unlockAchievement({
    required String userId,
    required String name,
    required String type,
    String? description,
    String? icon,
  }) async {
    final existing = await _achievementRepository.getByUserId(userId);
    final duplicate = existing.where((achievement) =>
        achievement.achievementType == type || achievement.name == name);
    if (duplicate.isNotEmpty && duplicate.first.isUnlocked) {
      return null;
    }

    final achievement = Achievement(
      userId: userId,
      name: name,
      description: description,
      achievementType: type,
      icon: icon,
      isUnlocked: true,
      unlockedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );

    if (duplicate.isEmpty) {
      await _achievementRepository.insert(achievement);
      return achievement;
    }

    final current = duplicate.first;
    final updated = current.copyWith(
      name: name,
      description: description,
      achievementType: type,
      icon: icon,
      isUnlocked: true,
      unlockedAt: DateTime.now(),
    );
    await _achievementRepository.update(updated);
    return updated;
  }

  Future<Reward?> claimReward({
    required String userId,
    required String type,
    required String title,
    required int amount,
    String? icon,
  }) async {
    final existing = await _rewardRepository.getByUserAndType(userId, type, title);
    if (existing != null && existing.isClaimed) {
      return null;
    }

    final reward = Reward(
      userId: userId,
      type: type,
      title: title,
      amount: amount,
      icon: icon,
      isClaimed: true,
      claimedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (existing == null) {
      await _rewardRepository.insert(reward);
      return reward;
    }

    final updated = existing.copyWith(
      amount: amount,
      icon: icon,
      isClaimed: true,
      claimedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _rewardRepository.update(updated);
    return updated;
  }

  Future<Challenge?> upsertChallenge({
    required String userId,
    required String type,
    required String title,
    required String description,
    required String difficulty,
    required int target,
    int rewardXp = 0,
    int progress = 0,
    bool isCompleted = false,
  }) async {
    final existing = await _challengeRepository.getByUserAndType(userId, type);
    final now = DateTime.now();

    if (existing != null) {
      final updated = existing.copyWith(
        title: title,
        description: description,
        difficulty: difficulty,
        target: target,
        progress: progress,
        rewardXp: rewardXp,
        isCompleted: isCompleted,
        completedAt: isCompleted ? (existing.completedAt ?? now) : null,
        updatedAt: now,
      );
      await _challengeRepository.update(updated);
      return updated;
    }

    final challenge = Challenge(
      userId: userId,
      title: title,
      type: type,
      description: description,
      difficulty: difficulty,
      target: target,
      progress: progress,
      rewardXp: rewardXp,
      isCompleted: isCompleted,
      completedAt: isCompleted ? now : null,
      createdAt: now,
      updatedAt: now,
    );
    await _challengeRepository.insert(challenge);
    return challenge;
  }
}
