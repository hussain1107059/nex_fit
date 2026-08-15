import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/progress/goal_progress.dart';
import '../../../l10n/app_localizations.dart';
import '../../../presentation/router/app_router.dart';
import '../../providers/progress_providers.dart';
import 'widgets/progress_widgets.dart';

/// Live progress towards every tracked goal (weight, workout, calories,
/// water, steps, sleep).
class GoalProgressScreen extends ConsumerWidget {
  const GoalProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GoalProgress>> async = ref.watch(goalProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.progressGoalsTitle),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push(AppRoutes.progressGoalManagement),
            icon: const Icon(Icons.settings_rounded),
            tooltip: context.l10n.goalManagementTitle,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(goalProgressProvider),
        ),
        data: (List<GoalProgress> goals) => goals.isEmpty
            ? const _EmptyGoals()
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                children: <Widget>[
                  for (int i = 0; i < goals.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: AppSpacing.sm),
                    GoalProgressTile(goal: goals[i]),
                  ],
                ],
              ),
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.flag_rounded,
                  size: 48,
                  color: context.colorScheme.outlineVariant,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.progressGoalNotSet,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.progressEmptySubtitle,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
