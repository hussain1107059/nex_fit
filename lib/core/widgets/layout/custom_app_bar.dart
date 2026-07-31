import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../effects/glass_container.dart';
import '../../extensions/context_extensions.dart';

/// Custom app bar with optional glass style, leading and trailing actions.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showBackButton = false,
    this.actions,
    this.glass = false,
    this.leading,
    this.onBackPressed,
    this.bottom,
    this.centerTitle = false,
  });

  final String? title;
  final Widget? titleWidget;
  final bool showBackButton;
  final List<Widget>? actions;
  final bool glass;
  final Widget? leading;
  final VoidCallback? onBackPressed;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final Widget? effectiveLeading = leading ??
        (showBackButton
            ? IconButton(
                onPressed: onBackPressed ?? () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                tooltip: context.l10n.commonBack,
              )
            : null);

    final Widget bar = AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      leading: effectiveLeading,
      toolbarHeight: kToolbarHeight,
      titleSpacing: showBackButton ? 0 : AppSpacing.xs,
      title: titleWidget ??
          (title != null
              ? Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null),
      actions: actions,
      bottom: bottom,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    );

    if (!glass) return bar;

    return GlassContainer(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(context.isWide ? 24 : 20),
      ),
      opacity: 0.7,
      padding: EdgeInsets.zero,
      child: bar,
    );
  }
}
