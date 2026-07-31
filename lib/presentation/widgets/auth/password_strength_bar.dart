import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';

/// Live password strength meter used on the registration screen.
class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.password});

  final String password;

  int get _score {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= AppConstants.strongPasswordLength) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[^A-Za-z0-9]'))) score++;
    return score;
  }

  String? _label(AppLocalizations l10n) {
    if (password.isEmpty) return null;
    return switch (_score) {
      <= 2 => l10n.authPasswordStrengthWeak,
      3 => l10n.authPasswordStrengthMedium,
      _ => l10n.authPasswordStrengthStrong,
    };
  }

  Color _color(ColorScheme scheme) {
    return switch (_score) {
      <= 2 => scheme.error,
      3 => scheme.secondary,
      _ => scheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final String? label = _label(context.l10n);
    if (label == null) return const SizedBox.shrink();

    final Color color = _color(context.colorScheme);
    final double fraction = _score / 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadius.pillRadius,
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              color: color,
              backgroundColor: context.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
