import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import 'motivational_quotes.dart';

/// Daily rotating motivational quote card.
class MotivationCard extends StatelessWidget {
  const MotivationCard({super.key, required this.quoteIndex});

  final int quoteIndex;

  @override
  Widget build(BuildContext context) {
    final List<MotivationalQuote> quotes = MotivationalQuotes.all;
    final MotivationalQuote quote =
        quotes[quoteIndex % quotes.length];
    final bool isBangla = Localizations.localeOf(context).languageCode == 'bn' ||
        Localizations.localeOf(context).languageCode == 'bs';
    final String text = isBangla ? quote.bangla : quote.english;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.xlRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colorScheme.tertiaryContainer.withValues(alpha: 0.7),
            context.colorScheme.secondaryContainer.withValues(alpha: 0.5),
          ],
        ),
        border: Border.all(color: context.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: context.colorScheme.tertiary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.format_quote_rounded,
              size: 22,
              color: context.colorScheme.onTertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.dashboardMotivation,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '"$text"',
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    height: 1.45,
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
