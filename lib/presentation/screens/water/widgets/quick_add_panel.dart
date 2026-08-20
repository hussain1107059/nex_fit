import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/water_providers.dart';
import 'water_sheets.dart';

/// Quick-add buttons (100 ml .. 1000 ml) plus the custom amount action.
class QuickAddPanel extends ConsumerWidget {
  const QuickAddPanel({super.key});

  static const List<int> _presets = <int>[100, 200, 250, 500, 750, 1000];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final Color accent = Theme.of(context).colorScheme.tertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                l10n.waterQuickAdd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => showCustomWaterSheet(context, ref),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(l10n.waterCustomAmount, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final int preset in _presets)
              _QuickAddChip(
                amountMl: preset,
                color: accent,
                onTap: () async {
                  await addWaterEntry(ref, preset);
                  if (context.mounted) {
                    AppSnackbar.success(context, l10n.waterLogSuccess);
                  }
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickAddChip extends StatelessWidget {
  const _QuickAddChip({
    required this.amountMl,
    required this.color,
    required this.onTap,
  });

  final int amountMl;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label = '+${amountMl.toString().toBanglaDigits()}';
    final ThemeData theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.water_drop_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                context.l10n.dashboardMlUnit,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
