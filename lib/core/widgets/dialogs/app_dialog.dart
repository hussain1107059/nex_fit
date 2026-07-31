import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../buttons/app_button.dart';
import '../../extensions/context_extensions.dart';

/// Prebuilt premium dialogs.
class AppDialog {
  AppDialog._();

  /// Generic alert dialog.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? message,
    Widget? content,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: content ?? (message != null ? Text(message) : null),
          actions: actions,
        );
      },
    );
  }

  /// Confirmation dialog with a destructive primary action.
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    bool destructive = false,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel ?? context.l10n.commonCancel),
            ),
            AppButton(
              onPressed: () => Navigator.of(context).pop(true),
              label: confirmLabel ?? context.l10n.commonConfirm,
              variant: destructive
                  ? AppButtonVariant.danger
                  : AppButtonVariant.primary,
              fullWidth: false,
              size: AppButtonSize.small,
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Premium success dialog with an animated check mark.
  static Future<void> success({
    required BuildContext context,
    required String title,
    String? message,
    String? okLabel,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (BuildContext context, double value, Widget? child) {
              return Transform.scale(scale: value, child: child);
            },
            child: CircleAvatar(
              radius: 34,
              backgroundColor: context.colorScheme.primaryContainer,
              child: Icon(
                Icons.check_rounded,
                size: 40,
                color: context.colorScheme.primary,
              ),
            ),
          ),
          title: Text(title, textAlign: TextAlign.center),
          content: message != null
              ? Text(message, textAlign: TextAlign.center)
              : null,
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            AppButton(
              onPressed: () => Navigator.of(context).pop(),
              label: okLabel ?? context.l10n.commonOk,
              fullWidth: false,
            ),
          ],
        );
      },
    );
  }
}
