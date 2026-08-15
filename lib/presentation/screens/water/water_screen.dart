import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_formatting.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/daily_hydration.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/water_providers.dart';
import '../../router/app_router.dart';
import 'widgets/entry_tile.dart';
import 'widgets/quick_add_panel.dart';
import 'widgets/water_glass.dart';
import 'widgets/water_sheets.dart';

/// Water tracker & hydration module home.
class WaterScreen extends ConsumerWidget {
  const WaterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final AsyncValue<DailyHydration> async = ref.watch(
      waterDailyControllerProvider,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(waterDailyControllerProvider.notifier).refresh(),
          child: async.when(
            data: (DailyHydration data) => _WaterContent(data: data),
            error: (Object error, StackTrace stackTrace) => _WaterError(
              onRetry: () => ref
                  .read(waterDailyControllerProvider.notifier)
                  .refresh(),
            ),
            loading: () => const LoadingWidget(message: null),
          ),
        ),
      ),
    );
  }
}

class _WaterContent extends ConsumerWidget {
  const _WaterContent({required this.data});

  final DailyHydration data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final DateTime selected = ref.watch(waterSelectedDateProvider);
    final DateTime today = DateTime.now();
    final DateTime todayStart = DateTime(today.year, today.month, today.day);
    final bool isToday = selected == todayStart;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          automaticallyImplyLeading: true,
          pinned: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          title: Text(
            l10n.waterTracker,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => context.push(AppRoutes.waterHistory),
              icon: const Icon(Icons.history_rounded),
              tooltip: l10n.waterHistory,
            ),
            IconButton(
              onPressed: () => context.push(AppRoutes.waterStatistics),
              icon: const Icon(Icons.bar_chart_rounded),
              tooltip: l10n.waterStatistics,
            ),
            IconButton(
              onPressed: () => context.push(AppRoutes.waterReminders),
              icon: const Icon(Icons.notifications_active_rounded),
              tooltip: l10n.waterReminders,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DateNavigator(selected: selected),
                    const SizedBox(height: AppSpacing.md),
                    _HydrationHeroCard(data: data),
                    const SizedBox(height: AppSpacing.md),
                    const QuickAddPanel(),
                    const SizedBox(height: AppSpacing.lg),
                    _GoalCard(data: data),
                    const SizedBox(height: AppSpacing.lg),
                    _EntriesSection(data: data, isToday: isToday),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateNavigator extends ConsumerWidget {
  const _DateNavigator({required this.selected});

  final DateTime selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final DateTime today = DateTime.now();
    final DateTime todayStart = DateTime(today.year, today.month, today.day);
    final bool isToday = selected == todayStart;

    return Row(
      children: [
        IconButton.outlined(
          onPressed: () {
            ref.read(waterSelectedDateProvider.notifier).state =
                selected.subtract(const Duration(days: 1));
          },
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: l10n.commonBack,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                formatWaterDate(selected, l10n),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isToday
                    ? l10n.commonToday
                    : '${selected.difference(todayStart).inDays.abs().toString().toBanglaDigits()} '
                          '${selected.isAfter(todayStart) ? l10n.nutritionDaysLater : l10n.nutritionDaysAgo}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton.outlined(
          onPressed: isToday
              ? null
              : () {
                  ref.read(waterSelectedDateProvider.notifier).state =
                      selected.add(const Duration(days: 1));
                },
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: l10n.commonNext,
        ),
      ],
    );
  }
}

class _HydrationHeroCard extends ConsumerWidget {
  const _HydrationHeroCard({required this.data});

  final DailyHydration data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Color accent = theme.colorScheme.tertiary;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.tertiaryContainer.withValues(alpha: 0.6),
              theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            ],
          ),
          borderRadius: AppRadius.lgRadius,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            WaterGlass(ratio: data.ratio, size: 130),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data.intakeMl.toString().toBanglaDigits()} / '
                    '${data.goalMl.toString().toBanglaDigits()} ${l10n.dashboardMlUnit}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StatusChip(status: data.status),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${l10n.waterRemaining}: '
                    '${data.remainingMl.toString().toBanglaDigits()} ${l10n.dashboardMlUnit}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.waterGoalProgress}: '
                    '${(data.ratio * 100).round().toString().toBanglaDigits()}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: data.ratio,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surface.withValues(
                        alpha: 0.6,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final HydrationStatus status;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final (IconData icon, Color color, String label) = switch (status) {
      HydrationStatus.needsWater => (
        Icons.local_drink_rounded,
        theme.colorScheme.primary,
        l10n.waterStatusNeedsWater,
      ),
      HydrationStatus.gettingThere => (
        Icons.trending_up_rounded,
        theme.colorScheme.secondary,
        l10n.waterStatusGettingThere,
      ),
      HydrationStatus.nearlyThere => (
        Icons.done_all_rounded,
        theme.colorScheme.tertiary,
        l10n.waterStatusNearlyThere,
      ),
      HydrationStatus.goalMet => (
        Icons.check_circle_rounded,
        theme.colorScheme.primary,
        l10n.waterStatusGoalMet,
      ),
      HydrationStatus.exceeded => (
        Icons.emoji_events_rounded,
        theme.colorScheme.secondary,
        l10n.waterStatusExceeded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.data});

  final DailyHydration data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppCard(
      onPressed: () =>
          showWaterGoalSheet(context, ref, data.goalMl),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.flag_rounded,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.waterDailyGoal,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${data.goalMl.toString().toBanglaDigits()} ${l10n.dashboardMlUnit}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            l10n.waterEditGoal,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _EntriesSection extends ConsumerWidget {
  const _EntriesSection({required this.data, required this.isToday});

  final DailyHydration data;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${l10n.waterEntries} (${data.entries.length.toString().toBanglaDigits()})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (isToday)
              TextButton.icon(
                onPressed: () => showCustomWaterSheet(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.waterCustomAmount),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (data.entries.isEmpty)
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Column(
                children: [
                  Icon(
                    Icons.water_drop_outlined,
                    size: 44,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.waterNoEntries,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.waterNoEntriesSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...data.entries.map((log) => WaterEntryTile(log: log)),
      ],
    );
  }
}

class _WaterError extends StatelessWidget {
  const _WaterError({required this.onRetry});

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
                title: context.l10n.errorDatabase,
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

/// Local date label shared by the water screens.
String formatWaterDate(DateTime date, AppLocalizations l10n) {
  return formatLocalizedDate(date, l10n);
}
