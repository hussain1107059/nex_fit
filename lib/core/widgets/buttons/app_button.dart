import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../extensions/context_extensions.dart';
import '../../extensions/string_extensions.dart';

/// Predefined visual styles for [AppButton].
enum AppButtonVariant { primary, secondary, outline, text, danger }

/// Reusable premium button with loading, disabled and icon support.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.iconTrailing,
    this.isLoading = false,
    this.isDisabled = false,
    this.fullWidth = true,
    this.size = AppButtonSize.medium,
    this.padding,
  });

  final VoidCallback? onPressed;
  final String label;
  final AppButtonVariant variant;
  final IconData? icon;
  final IconData? iconTrailing;
  final bool isLoading;
  final bool isDisabled;
  final bool fullWidth;
  final AppButtonSize size;
  final EdgeInsetsGeometry? padding;

  bool get _isInteractive => onPressed != null && !isLoading && !isDisabled;

  @override
  Widget build(BuildContext context) {
    final Widget content = _content(context);

    final Widget button = switch (variant) {
      AppButtonVariant.primary => _primary(context, content),
      AppButtonVariant.secondary => _secondary(context, content),
      AppButtonVariant.outline => _outline(context, content),
      AppButtonVariant.text => _text(context, content),
      AppButtonVariant.danger => _danger(context, content),
    };

    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _content(BuildContext context) {
    final TextStyle labelStyle = _labelStyle(context);

    final Widget labelWidget = isLoading
        ? SizedBox(
            width: size == AppButtonSize.small ? 16 : 20,
            height: size == AppButtonSize.small ? 16 : 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _foregroundColor(context),
              ),
            ),
          )
        : Text(label, style: labelStyle);

    if (icon == null && iconTrailing == null) {
      return Center(child: labelWidget);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: _foregroundColor(context)),
          8.widthSpace,
        ],
        labelWidget,
        if (iconTrailing != null) ...[
          8.widthSpace,
          Icon(iconTrailing, size: 20, color: _foregroundColor(context)),
        ],
      ],
    );
  }

  TextStyle _labelStyle(BuildContext context) {
    final double fontSize = switch (size) {
      AppButtonSize.small => 13.0,
      AppButtonSize.medium => 14.0,
      AppButtonSize.large => 16.0,
    };
    return context.textTheme.labelLarge!.copyWith(fontSize: fontSize);
  }

  Color _foregroundColor(BuildContext context) {
    return switch (variant) {
      AppButtonVariant.primary => context.colorScheme.onPrimary,
      AppButtonVariant.secondary => context.colorScheme.onPrimaryContainer,
      AppButtonVariant.outline => context.colorScheme.primary,
      AppButtonVariant.text => context.colorScheme.primary,
      AppButtonVariant.danger => context.colorScheme.onError,
    };
  }

  EdgeInsets _defaultPadding() {
    final double horizontal = switch (size) {
      AppButtonSize.small => AppSpacing.md,
      AppButtonSize.medium => AppSpacing.xl,
      AppButtonSize.large => AppSpacing.xxl,
    };
    final double vertical = switch (size) {
      AppButtonSize.small => AppSpacing.sm,
      AppButtonSize.medium => AppSpacing.md,
      AppButtonSize.large => AppSpacing.lg,
    };
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  BorderRadius _radius() {
    return switch (size) {
      AppButtonSize.small => AppRadius.smRadius,
      _ => AppRadius.mdRadius,
    };
  }

  Widget _primary(BuildContext context, Widget child) {
    return Material(
      color: _isInteractive
          ? context.colorScheme.primary
          : context.colorScheme.onSurface.withValues(alpha: 0.12),
      borderRadius: _radius(),
      elevation: _isInteractive ? 0 : 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: _isInteractive ? onPressed : null,
        borderRadius: _radius(),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: _radius(),
            gradient: _isInteractive
                ? const LinearGradient(
                    colors: [Color(0xFF0E9F6E), Color(0xFF22C55E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Container(
            padding: padding ?? _defaultPadding(),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _secondary(BuildContext context, Widget child) {
    return Material(
      color: _isInteractive
          ? context.colorScheme.primaryContainer
          : context.colorScheme.onSurface.withValues(alpha: 0.12),
      borderRadius: _radius(),
      child: InkWell(
        onTap: _isInteractive ? onPressed : null,
        borderRadius: _radius(),
        child: Container(
          padding: padding ?? _defaultPadding(),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  Widget _outline(BuildContext context, Widget child) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: _radius()),
      child: InkWell(
        onTap: _isInteractive ? onPressed : null,
        borderRadius: _radius(),
        child: Container(
          padding: padding ?? _defaultPadding(),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: _radius(),
            border: Border.all(
              color: _isInteractive
                  ? context.colorScheme.outline
                  : context.colorScheme.outlineVariant,
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _text(BuildContext context, Widget child) {
    return InkWell(
      onTap: _isInteractive ? onPressed : null,
      borderRadius: _radius(),
      child: Container(
        padding: padding ?? _defaultPadding(),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _danger(BuildContext context, Widget child) {
    return Material(
      color: _isInteractive
          ? context.colorScheme.error
          : context.colorScheme.onSurface.withValues(alpha: 0.12),
      borderRadius: _radius(),
      shadowColor: context.colorScheme.error.withValues(alpha: 0.4),
      child: InkWell(
        onTap: _isInteractive ? onPressed : null,
        borderRadius: _radius(),
        child: Container(
          padding: padding ?? _defaultPadding(),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: _radius(),
            boxShadow: _isInteractive ? AppShadows.soft : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

enum AppButtonSize { small, medium, large }
