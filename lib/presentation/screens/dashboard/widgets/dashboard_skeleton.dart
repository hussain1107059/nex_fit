import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/effects/app_shimmer.dart';

/// Skeleton loading layout shown while the dashboard aggregates its data.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(width: 120, height: 12),
                    SizedBox(height: AppSpacing.sm),
                    ShimmerBox(width: 180, height: 22),
                  ],
                ),
              ),
              const ShimmerBox(width: 48, height: 48, shape: BoxShape.circle),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const ShimmerBox(height: 48, radius: AppRadius.md),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerBox(height: 210, radius: AppRadius.xl),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerBox(width: 120, height: 14),
          const SizedBox(height: AppSpacing.sm),
          const ShimmerBox(height: 92, radius: AppRadius.md),
          const SizedBox(height: AppSpacing.sm),
          const ShimmerBox(height: 92, radius: AppRadius.md),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerBox(width: 120, height: 14),
          const SizedBox(height: AppSpacing.sm),
          const ShimmerBox(height: 150, radius: AppRadius.lg),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerBox(width: 120, height: 14),
          const SizedBox(height: AppSpacing.sm),
          const ShimmerBox(height: 120, radius: AppRadius.lg),
        ],
      ),
    );
  }
}
