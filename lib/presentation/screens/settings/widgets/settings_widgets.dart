import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards/app_card.dart';

/// Section heading used between groups of settings.
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        style: context.textTheme.labelLarge?.copyWith(
          color: context.colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// A rounded surface grouping related settings tiles.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      showShadow: false,
      borderRadius: AppRadius.lgRadius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Tappable settings row with an icon, title, optional subtitle and value.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.iconColor,
    this.trailing,
    this.showChevron = true,
    this.enabled = true,
    this.destructive = false,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Widget? trailing;
  final bool showChevron;
  final bool enabled;
  final bool destructive;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final Color accent = destructive ? scheme.error : (iconColor ?? scheme.primary);
    return ListTile(
      selected: selected,
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      leading: Icon(icon, color: accent),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: destructive ? scheme.error : null,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: context.textTheme.bodySmall?.copyWith(
                color: destructive ? scheme.error : scheme.onSurfaceVariant,
              ),
            ),
      trailing: selected && !destructive
          ? Icon(Icons.check_rounded, color: scheme.primary)
          : trailing != null
                // Custom trailing widgets (e.g. wide action buttons) can
                // overflow ListTile's fixed trailing box with long Bangla
                // labels. Scale them down to fit instead of overflowing.
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: trailing,
                    ),
                  )
                : (showChevron
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (value != null)
                              Flexible(
                                child: Text(
                                  value!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textTheme.bodyMedium
                                      ?.copyWith(
                                        color: destructive
                                            ? scheme.error
                                            : scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            const SizedBox(width: AppSpacing.xs),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: destructive
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ],
                        )
                      : (value != null
                            ? Text(
                                value!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: destructive
                                      ? scheme.error
                                      : scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null)),
      onTap: enabled ? onTap : null,
    );
  }
}

/// Settings row backed by a [SwitchListTile].
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.iconColor,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? iconColor;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      secondary: Icon(icon, color: iconColor ?? context.colorScheme.primary),
      title: Text(
        title,
        style: context.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

/// A single selectable option shown inside a picker sheet.
class SettingsChoice<T> {
  const SettingsChoice({required this.label, required this.value});

  final String label;
  final T value;
}

/// Opens a modal bottom sheet offering [choices]. Returns the selected value,
/// or null when dismissed.
Future<T?> showSettingsChoices<T>({
  required BuildContext context,
  required String title,
  required IconData icon,
  required List<SettingsChoice<T>> choices,
  required T current,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return Container(
        decoration: BoxDecoration(
          color: sheetContext.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: sheetContext.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: sheetContext.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final SettingsChoice<T> choice in choices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    choice.value == current
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: choice.value == current
                        ? sheetContext.colorScheme.primary
                        : sheetContext.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    choice.label,
                    style: TextStyle(
                      fontWeight: choice.value == current
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(choice.value),
                ),
            ],
          ),
        ),
      );
    },
  );
}
