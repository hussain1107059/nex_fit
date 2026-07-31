import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../extensions/context_extensions.dart';
import '../../extensions/string_extensions.dart';

/// Full-bleed loading indicator with optional message and progress bar.
class LoadingWidget extends StatelessWidget {
  const LoadingWidget({
    super.key,
    this.message,
    this.compact = false,
  });

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: context.colorScheme.primary,
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: context.colorScheme.primary,
              backgroundColor: context.colorScheme.surfaceContainerHighest,
            ),
          ),
          if (message != null) ...[
            AppSpacing.lg.heightSpace,
            Text(
              message!,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
