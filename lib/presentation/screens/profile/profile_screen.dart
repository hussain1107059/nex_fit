import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/effects/app_shimmer.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../domain/entities/profile_data.dart';
import '../../providers/dashboard_providers.dart';
import '../../providers/profile_providers.dart';
import '../../router/app_router.dart';
import 'widgets/profile_bmi_card.dart';
import 'widgets/profile_energy_card.dart';
import 'widgets/profile_goal_card.dart';
import 'widgets/profile_grid_cards.dart';
import 'widgets/profile_header_card.dart';
import 'widgets/profile_settings_card.dart';
import 'widgets/profile_statistics_card.dart';

/// Premium profile tab backed entirely by the local database.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen<int>(shellTabIndexProvider, (int? previous, int next) {
      if (next == 4 && previous != null && previous != 4) {
        ref.read(profileControllerProvider.notifier).refresh();
      }
    });

    final AsyncValue<ProfileData> async = ref.watch(profileControllerProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(profileControllerProvider.notifier).refresh(),
          child: async.when(
            data: (ProfileData data) => _ProfileContent(data: data),
            error: (Object error, StackTrace stackTrace) => _ProfileError(
              onRetry: () =>
                  ref.read(profileControllerProvider.notifier).refresh(),
            ),
            loading: () => const _ProfileSkeleton(),
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.data});

  final ProfileData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool hasProfile = data.profile != null;

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
                ProfileHeaderCard(data: data),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  onPressed: () => context.push(AppRoutes.profileEdit),
                  label: context.l10n.profileEditProfile,
                  variant: AppButtonVariant.outline,
                  icon: Icons.edit_rounded,
                ),
                if (!hasProfile) ...[
                  const SizedBox(height: AppSpacing.md),
                  const _CompleteProfileCard(),
                ],
                const SizedBox(height: AppSpacing.lg),
                ProfilePhysicalCard(profile: data.profile),
                ProfileGoalCard(profile: data.profile),
                ProfileBmiCard(profile: data.profile),
                ProfileEnergyCard(profile: data.profile),
                ProfileTargetsCard(profile: data.profile),
                ProfileStatisticsCard(stats: data.stats),
                const ProfileSettingsCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CompleteProfileCard extends StatelessWidget {
  const _CompleteProfileCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: AppRadius.xlRadius,
        border: Border.all(
          color: context.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.rocket_launch_rounded,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.profileCompleteProfile,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  context.l10n.profileCompleteProfileSubtitle,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});

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

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
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
            child: AppShimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 280,
                    decoration: BoxDecoration(
                      color: context.colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: AppRadius.xlRadius,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const ShimmerBox(height: 48, radius: 16),
                  const SizedBox(height: AppSpacing.lg),
                  const ShimmerBox(height: 140, radius: 20),
                  const SizedBox(height: AppSpacing.md),
                  const ShimmerBox(height: 140, radius: 20),
                  const SizedBox(height: AppSpacing.md),
                  const ShimmerBox(height: 180, radius: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
