import 'package:flutter/material.dart';

import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';

/// Stepper for selecting a food serving quantity.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.min = 0.5,
    this.max = 10,
    this.step = 0.5,
  });

  final double quantity;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Button(
          icon: Icons.remove_rounded,
          onPressed: quantity > min
              ? () => onChanged((quantity - step).clamp(min, max))
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            _format(quantity),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _Button(
          icon: Icons.add_rounded,
          onPressed: quantity < max
              ? () => onChanged((quantity + step).clamp(min, max))
              : null,
        ),
      ],
    );
  }

  String _format(double value) {
    final bool whole = value == value.roundToDouble();
    return (whole ? value.round().toString() : value.toStringAsFixed(1))
        .toBanglaDigits();
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = onPressed != null;
    return Material(
      color: enabled
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

