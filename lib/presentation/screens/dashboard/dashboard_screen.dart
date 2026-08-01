import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/dashboard_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_providers.dart';
import 'widgets/achievements_section.dart';
import 'widgets/backup_card.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_skeleton.dart';
import 'widgets/dashboard_summary_card.dart';
import 'widgets/gamification_overview_card.dart';
import 'widgets/empty_weight_card.dart';
import 'widgets/motivation_card.dart';
import 'widgets/quick_actions_section.dart';
import 'widgets/recent_activity_section.dart';
import 'widgets/reminders_section.dart';
import 'widgets/search_results_card.dart';
import 'widgets/today_goals_section.dart';
import 'widgets/weekly_stats_section.dart';

/// Premium home dashboard backed entirely by the local database.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen<int>(shellTabIndexProvider, (int? previous, int next) {
      if (next == 0 && previous != null && previous != 0) {
        ref.read(dashboardControllerProvider.notifier).refresh();
      }
    });

    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final AsyncValue<DashboardData> async = ref.watch(
      dashboardControllerProvider,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(dashboardControllerProvider.notifier).refresh(),
          child: async.when(
            data: (DashboardData data) => _DashboardContent(
              data: data,
              user: user,
              query: ref.watch(searchQueryProvider),
            ),
            error: (Object error, StackTrace stackTrace) => _DashboardError(
              onRetry: () =>
                  ref.read(dashboardControllerProvider.notifier).refresh(),
            ),
            loading: () => const DashboardSkeleton(),
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.data,
    required this.user,
    required this.query,
  });

  final DashboardData data;
  final AppUser user;
  final String query;

  @override
  Widget build(BuildContext context) {
    final String searchQuery = query.trim();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DashboardHeader(user: user),
                if (searchQuery.isNotEmpty) ...[
                  const SearchResultsCard(),
                  const SizedBox(height: AppSpacing.md),
                ],
                const SizedBox(height: AppSpacing.md),
                DashboardSummaryCard(summary: data.summary),
                const SizedBox(height: AppSpacing.lg),
                const BackupCard(),
                const SizedBox(height: AppSpacing.lg),
                const GamificationOverviewCard(),
                if (!data.summary.hasWeight) ...[
                  const SizedBox(height: AppSpacing.lg),
                  EmptyWeightCard(userId: user.id),
                ],
                const SizedBox(height: AppSpacing.lg),
                QuickActionsSection(userId: user.id, summary: data.summary),
                const SizedBox(height: AppSpacing.lg),
                TodayGoalsSection(goals: data.goals),
                const SizedBox(height: AppSpacing.lg),
                RecentActivitySection(data: data),
                const SizedBox(height: AppSpacing.lg),
                MotivationCard(quoteIndex: data.quoteIndex),
                const SizedBox(height: AppSpacing.lg),
                AchievementsSection(achievement: data.achievement),
                const SizedBox(height: AppSpacing.lg),
                RemindersSection(reminders: data.reminders),
                const SizedBox(height: AppSpacing.lg),
                WeeklyStatsSection(data: data),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: ErrorWidget(
                title: context.l10n.dashboardLoadError,
                subtitle: context.l10n.errorDatabaseSubtitle,
                onRetry: onRetry,
              ),
            ),
          ],
        );
      },
    );
  }
}
