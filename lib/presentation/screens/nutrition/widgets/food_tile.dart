import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../domain/entities/food_item.dart';

/// A food row used across the food database and meal logging screens.
class FoodTile extends StatelessWidget {
  const FoodTile({
    super.key,
    required this.food,
    this.onTap,
    this.onFavoriteTap,
    this.trailing,
    this.showFavorite = true,
  });

  final FoodItem food;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final Widget? trailing;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      onPressed: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        food.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${food.servingSize ?? '${food.servingGrams?.round() ?? 0}g'} · '
                  '${food.calories.round()} ${context.l10n.dashboardKcalUnit}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                _MacroRow(food: food),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
          if (showFavorite) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              onPressed: onFavoriteTap,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                food.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 20,
                color: food.isFavorite
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.food});

  final FoodItem food;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> items = <Widget>[
      _chip(context, 'P ${_g(food.protein)}', theme.colorScheme.primary),
      const SizedBox(width: AppSpacing.sm),
      _chip(context, 'C ${_g(food.carbs)}', theme.colorScheme.secondary),
      const SizedBox(width: AppSpacing.sm),
      _chip(context, 'F ${_g(food.fat)}', theme.colorScheme.tertiary),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: items,
    );
  }

  Widget _chip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _g(double value) => value.toStringAsFixed(0).toBanglaDigits();
}
