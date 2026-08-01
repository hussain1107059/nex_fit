import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../providers/nutrition_providers.dart';

/// 7/14/30 day range selector shared by the macro tracker and history screens.
class HistoryRangeSelector extends ConsumerWidget {
  const HistoryRangeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ({DateTime start, DateTime end}) range = ref.watch(
      nutritionHistoryRangeProvider,
    );
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int days = range.end.difference(range.start).inDays + 1;

    Widget chip(int value) {
      final bool selected = days == value;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xs),
        child: ChoiceChip(
          label: Text(
            '${value.toString().toBanglaDigits()} '
            '${context.l10n.nutritionDaysShort}',
          ),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) {
            ref.read(nutritionHistoryRangeProvider.notifier).state = (
              start: today.subtract(Duration(days: value - 1)),
              end: today,
            );
          },
        ),
      );
    }

    return Row(children: [chip(7), chip(14), chip(30)]);
  }
}
