import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards/app_card.dart';
import '../../../../core/widgets/dialogs/app_dialog.dart';
import '../../../../domain/entities/food_log.dart';
import '../../../../domain/entities/food_log_entry.dart';
import '../../../../domain/entities/meal_slot.dart';
import '../../../providers/nutrition_providers.dart';
import 'meal_category_icon.dart';
import 'quantity_stepper.dart';

/// A collapsible card for one meal slot of the day with its logged foods.
class MealSlotCard extends ConsumerStatefulWidget {
  const MealSlotCard({
    super.key,
    required this.slot,
    this.onAddPressed,
    this.defaultExpanded = true,
  });

  final MealSlot slot;
  final VoidCallback? onAddPressed;
  final bool defaultExpanded;

  @override
  ConsumerState<MealSlotCard> createState() => _MealSlotCardState();
}

class _MealSlotCardState extends ConsumerState<MealSlotCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.defaultExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final MealSlot slot = widget.slot;
    final bool empty = slot.isEmpty;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: AppRadius.lgRadius,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      mealCategoryIcon(slot.category.slug),
                      size: 20,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.category.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          empty
                              ? context.l10n.nutritionMealEmpty
                              : '${slot.itemCount.toString().toBanglaDigits()} '
                                    '${context.l10n.nutritionItems}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${slot.calories.round().toString().toBanglaDigits()} '
                        '${context.l10n.dashboardKcalUnit}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            if (empty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.nutritionNoFoodLogged,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: widget.onAddPressed,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(context.l10n.commonAdd),
                    ),
                  ],
                ),
              )
            else ...[
              ...slot.items.map(
                (FoodLogEntry entry) => _EntryRow(
                  key: ValueKey<int?>(entry.log.id),
                  entry: entry,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: widget.onAddPressed,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(context.l10n.commonAdd),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({super.key, required this.entry});

  final FoodLogEntry entry;

  Future<void> _editQuantity(BuildContext context, WidgetRef ref) async {
    final FoodLog log = entry.log;
    double selected = log.quantity;
    await AppDialog.show(
      context: context,
      title: context.l10n.nutritionEditQuantity,
      content: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              QuantityStepper(
                quantity: selected,
                onChanged: (double value) => setState(() => selected = value),
              ),
              const SizedBox(height: 8),
              Text(
                '${(log.calories / log.quantity * selected).round().toString().toBanglaDigits()} '
                '${context.l10n.dashboardKcalUnit}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            updateLogQuantity(ref, log: log, quantity: selected);
          },
          child: Text(context.l10n.commonSave),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String name = entry.food?.name ?? entry.log.servingSize ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${entry.log.quantity.toStringAsFixed(1).toBanglaDigits()}Ã— Â· '
                  'P ${entry.protein.toStringAsFixed(0).toBanglaDigits()} '
                  'C ${entry.carbs.toStringAsFixed(0).toBanglaDigits()} '
                  'F ${entry.fat.toStringAsFixed(0).toBanglaDigits()}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            entry.calories.round().toString().toBanglaDigits(),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            iconSize: 20,
            onSelected: (String value) {
              switch (value) {
                case 'edit':
                  _editQuantity(context, ref);
                case 'duplicate':
                  duplicateFoodLog(ref, entry.log.id!);
                case 'delete':
                  AppDialog.confirm(
                    context: context,
                    title: context.l10n.nutritionRemoveFood,
                    message: context.l10n.nutritionRemoveFoodMessage,
                    confirmLabel: context.l10n.commonDelete,
                    destructive: true,
                  ).then((bool? ok) {
                    if (ok == true) removeFoodFromLog(ref, entry.log.id!);
                  });
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(context.l10n.nutritionEditQuantity),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'duplicate',
                child: Row(
                  children: [
                    const Icon(Icons.content_copy_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(context.l10n.nutritionDuplicate),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.commonDelete,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

