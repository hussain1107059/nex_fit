import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';

/// Minimal foundation content shown for a module that is not built yet.
/// Real module screens will replace these during feature development.
class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.subtitle,
  });

  final String title;
  final String icon;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(title, style: context.textTheme.headlineSmall),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: context.colorScheme.primaryContainer
                            .withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset(
                        icon,
                        width: 44,
                        height: 44,
                        colorFilter: ColorFilter.mode(
                          context.colorScheme.primary,
                          BlendMode.srcIn,
                        ),
                        fit: BoxFit.none,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      subtitle,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      context.l10n.appTagline,
                      style: context.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
