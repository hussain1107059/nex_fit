import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/gamification_providers.dart';

class ProfileGamificationCard extends ConsumerWidget {
  const ProfileGamificationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      return const SizedBox.shrink();
    }

    final levelAsync = ref.watch(userLevelProvider);
    final xpAsync = ref.watch(xpHistoryProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: AppRadius.xlRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gamification',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          levelAsync.when(
            data: (level) {
              final currentLevel = level?.level ?? 1;
              final currentXp = level?.currentXp ?? 0;
              final totalXp = xpAsync.asData?.value.fold<int>(0, (sum, item) => sum + item.xp) ?? 0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MetricTile(label: 'Level', value: 'Lv $currentLevel'),
                  _MetricTile(label: 'XP', value: '$totalXp'),
                  _MetricTile(label: 'Progress', value: '$currentXp XP'),
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
