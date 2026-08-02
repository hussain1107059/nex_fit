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
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    final ColorScheme scheme = context.colorScheme;
    final Color background = switch (type) {
      AppSnackbarType.success => scheme.inverseSurface,
      AppSnackbarType.error => scheme.error,
      AppSnackbarType.info => scheme.inverseSurface,
    };
    final Color foreground = switch (type) {
      AppSnackbarType.success => scheme.onInverseSurface,
      AppSnackbarType.error => scheme.onError,
      AppSnackbarType.info => scheme.onInverseSurface,
    };
    final IconData icon = switch (type) {
      AppSnackbarType.success => Icons.check_circle_rounded,
      AppSnackbarType.error => Icons.error_rounded,
      AppSnackbarType.info => Icons.info_rounded,
    };

    final MaterialLocalizations localizations =
        MaterialLocalizations.of(context);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: foreground, size: 20),
              8.widthSpace,
              Expanded(
                child: Text(
                  message,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: background,
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
          ),
          action: SnackBarAction(
            label: localizations.closeButtonLabel,
            textColor: foreground,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
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
