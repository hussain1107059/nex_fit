import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/profile_data.dart';
import '../profile_labels.dart';
import 'profile_avatar.dart';

/// Gradient hero card with the profile picture, name, provider and member
/// since date.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({super.key, required this.data, this.onAvatarTap});

  final ProfileData data;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final AppColors appColors =
        context.isDarkMode ? AppColors.dark : AppColors.light;
    final Color onGradient = Colors.white;
    final String name = data.user.displayName?.trim().isNotEmpty == true
        ? data.user.displayName!.trim()
        : context.l10n.commonProfile;
    final String email = data.user.email ?? '';
    final String memberSince = data.user.createdAt == null
        ? '—'
        : DateFormat('d MMM yyyy')
            .format(data.user.createdAt!)
            .toBanglaDigits();

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: appColors.brandGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: appColors.primary.withValues(alpha: 0.3),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          ProfileAvatar(
            photoPath: data.profile?.photoPath,
            networkUrl: data.user.photoUrl,
            name: name,
            email: email,
            radius: 52,
            onTap: onAvatarTap,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.headlineSmall?.copyWith(
              color: onGradient,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              email,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                color: onGradient.withValues(alpha: 0.9),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: [
              _HeaderChip(
                icon: Icons.verified_user_rounded,
                label: ProfileLabels.provider(
                  context.l10n,
                  data.user.provider,
                ),
                onGradient: onGradient,
              ),
              _HeaderChip(
                icon: Icons.calendar_today_rounded,
                label:
                    '${context.l10n.profileMemberSince} $memberSince',
                onGradient: onGradient,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.onGradient,
  });

  final IconData icon;
  final String label;
  final Color onGradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: onGradient.withValues(alpha: 0.18),
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: onGradient.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: onGradient),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: context.textTheme.labelMedium?.copyWith(
              color: onGradient,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
