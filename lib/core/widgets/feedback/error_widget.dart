import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../buttons/app_button.dart';
import '../../extensions/context_extensions.dart';
import '../../extensions/string_extensions.dart';

/// Full state error placeholder with a retry action.
class ErrorWidget extends StatelessWidget {
  const ErrorWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colorScheme.errorContainer,
              ),
              child: Icon(
                icon,
                size: 40,
                color: context.colorScheme.error,
              ),
            ),
            AppSpacing.xl.heightSpace,
            Text(
              title,
              style: context.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              AppSpacing.xs.heightSpace,
              Text(
                subtitle!,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              AppSpacing.xl.heightSpace,
              AppButton(
                onPressed: onRetry,
                label: context.l10n.commonTryAgain,
                icon: Icons.refresh_rounded,
                variant: AppButtonVariant.outline,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
