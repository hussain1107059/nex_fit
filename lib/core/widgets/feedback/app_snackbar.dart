import 'package:flutter/material.dart';

import '../../extensions/context_extensions.dart';
import '../../extensions/string_extensions.dart';
import '../../theme/app_radius.dart';

/// Visual type of a snackbar.
enum AppSnackbarType { success, error, info }

/// Helper for showing consistent snackbars across the app.
class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
    Duration duration = const Duration(milliseconds: 2000),
  }) {
    final ColorScheme scheme = context.colorScheme;
    final IconData icon = switch (type) {
      AppSnackbarType.success => Icons.check_circle_rounded,
      AppSnackbarType.error => Icons.info_rounded,
      AppSnackbarType.info => Icons.info_rounded,
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: scheme.onInverseSurface, size: 20),
              8.widthSpace,
              Expanded(
                child: Text(
                  message,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: scheme.onInverseSurface,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: scheme.inverseSurface,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, type: AppSnackbarType.success);

  static void error(BuildContext context, String message) =>
      show(context, message, type: AppSnackbarType.error);

  static void info(BuildContext context, String message) =>
      show(context, message, type: AppSnackbarType.info);
}
