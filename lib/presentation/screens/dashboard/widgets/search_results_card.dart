import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/effects/app_shimmer.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../domain/entities/dashboard_data.dart';
import '../../../providers/dashboard_providers.dart';

/// Result panel shown under the search field while a query is active.
class SearchResultsCard extends ConsumerWidget {
  const SearchResultsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String query = ref.watch(searchQueryProvider);
    if (query.trim().isEmpty) return const SizedBox.shrink();

    final AsyncValue<List<GlobalSearchResult>> async = ref.watch(
      searchResultsProvider,
    );

    return async.when(
      data: (List<GlobalSearchResult> results) {
        if (results.isEmpty) {
          return _NoResults(message: context.l10n.emptyNoResults);
        }
        return Card(
          margin: const EdgeInsets.only(top: AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Group(
                  type: GlobalSearchType.workout,
                  results: results,
                ),
                _Group(
                  type: GlobalSearchType.exercise,
                  results: results,
                ),
                _Group(type: GlobalSearchType.food, results: results),
                _Group(type: GlobalSearchType.meal, results: results),
              ],
            ),
          ),
        );
      },
      error: (Object _, StackTrace _) => const SizedBox.shrink(),
      loading: () => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: AppShimmer(
          child: ShimmerBox(height: 96, radius: AppRadius.lg),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(
              Icons.search_off_rounded,
              color: context.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message, style: context.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.type, required this.results});

  final GlobalSearchType type;
  final List<GlobalSearchResult> results;

  @override
  Widget build(BuildContext context) {
    final List<GlobalSearchResult> matches = results
        .where((GlobalSearchResult r) => r.type == type)
        .toList();
    if (matches.isEmpty) return const SizedBox.shrink();

    final String title = switch (type) {
      GlobalSearchType.workout => context.l10n.dashboardSearchWorkouts,
      GlobalSearchType.exercise => context.l10n.dashboardSearchExercises,
      GlobalSearchType.food => context.l10n.dashboardSearchFoods,
      GlobalSearchType.meal => context.l10n.dashboardSearchMeals,
    };
    final IconData icon = switch (type) {
      GlobalSearchType.workout => Icons.fitness_center_rounded,
      GlobalSearchType.exercise => Icons.sports_gymnastics_rounded,
      GlobalSearchType.food => Icons.restaurant_menu_rounded,
      GlobalSearchType.meal => Icons.lunch_dining_rounded,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxs,
          ),
          child: Text(
            title,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
        for (final GlobalSearchResult result in matches)
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: context.colorScheme.primaryContainer,
              child: Icon(icon, size: 18, color: context.colorScheme.primary),
            ),
            title: Text(result.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: result.subtitle == null
                ? null
                : Text(result.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => AppSnackbar.info(
              context,
              context.l10n.dashboardComingSoon,
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}
