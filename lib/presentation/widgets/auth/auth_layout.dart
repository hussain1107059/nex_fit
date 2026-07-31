import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';

/// Shared layout for authentication screens.
///
/// Provides a premium gradient backdrop, responsive width constraints and a
/// gentle fade-and-slide entrance for the content.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.children,
    this.footer,
    this.showBackButton = false,
    this.onBackPressed,
  });

  final List<Widget> children;
  final Widget? footer;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.45, 1.0],
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.45),
              scheme.surface,
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              if (showBackButton)
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  child: IconButton.filledTonal(
                    onPressed: onBackPressed ?? () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    tooltip: context.l10n.commonBack,
                  ),
                ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.xxl,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 550),
                      curve: Curves.easeOutCubic,
                      builder: (BuildContext context, double value, Widget? child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 28 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...children,
                          if (footer != null) ...[
                            const SizedBox(height: AppSpacing.xxl),
                            footer!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
