import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../extensions/context_extensions.dart';
import '../../extensions/string_extensions.dart';

/// Empty state placeholder with icon, title, subtitle and optional action.
class EmptyWidget extends StatelessWidget {
  const EmptyWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actionLabel,
    this.onActionPressed,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

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
                color: context.colorScheme.primaryContainer
                    .withValues(alpha: 0.6),
              ),
              child: Icon(
                icon ?? Icons.inbox_outlined,
                size: 40,
                color: context.colorScheme.primary,
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
            if (actionLabel != null && onActionPressed != null) ...[
              AppSpacing.xl.heightSpace,
              TextButton.icon(
                onPressed: onActionPressed,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
