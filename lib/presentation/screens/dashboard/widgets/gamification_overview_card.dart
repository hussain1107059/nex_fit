import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/gamification_providers.dart';

class GamificationOverviewCard extends ConsumerWidget {
  const GamificationOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      return const SizedBox.shrink();
    }

    final levelAsync = ref.watch(userLevelProvider);
    final challengeAsync = ref.watch(activeChallengesProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlRadius,
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Gamification',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          levelAsync.when(
            data: (level) {
              final ratio = level == null ? 0.0 : (level.progressRatio).clamp(0.0, 1.0);
              final currentLevel = level?.level ?? 1;
              final requiredXp = level?.requiredXp ?? 100;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Level $currentLevel'),
                      Text('${level?.currentXp ?? 0} / $requiredXp XP'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ],
              );
            },
            loading: () => const LinearProgressIndicator(minHeight: 8),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.md),
          challengeAsync.when(
            data: (challenges) {
              final challenge = challenges.isNotEmpty ? challenges.first : null;
              return Row(
                children: [
                  const Icon(Icons.flag_rounded),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      challenge == null
                          ? 'No active challenge'
                          : '${challenge.title} • ${challenge.rewardXp} XP',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
