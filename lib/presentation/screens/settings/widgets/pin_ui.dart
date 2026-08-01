import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

/// Visualizes the currently entered PIN as filled / empty dots.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.length,
    required this.entered,
    this.onEntered,
    this.error = false,
  });

  final int length;
  final int entered;
  final ValueChanged<int>? onEntered;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < entered
                  ? (error ? scheme.error : scheme.primary)
                  : scheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
      ],
    );
  }
}

/// A numeric 0-9 keypad with a backspace key used by the app lock + PIN setup.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.biometricAvailable = false,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool biometricAvailable;

  @override
  Widget build(BuildContext context) {
    final List<String> keys = <String>[
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int row = 0; row < 3; row++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int col = 0; col < 3; col++)
                _KeyButton(
                  label: keys[row * 3 + col],
                  onTap: () => onDigit(keys[row * 3 + col]),
                ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KeyButton(
              label: '',
              leading: biometricAvailable
                  ? Icon(
                      Icons.fingerprint_rounded,
                      size: 28,
                      color: context.colorScheme.primary,
                    )
                  : null,
              onTap: biometricAvailable ? onBiometric : null,
            ),
            _KeyButton(label: '0', onTap: () => onDigit('0')),
            _KeyButton(
              label: '',
              leading: Icon(
                Icons.backspace_outlined,
                size: 24,
                color: context.colorScheme.onSurfaceVariant,
              ),
              onTap: onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.label, this.leading, this.onTap});

  final String label;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            ),
            child: leading ??
                Text(
                  label,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
