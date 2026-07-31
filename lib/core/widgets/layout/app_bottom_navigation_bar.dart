import 'package:flutter/material.dart';

import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../extensions/context_extensions.dart';

/// A single destination for the bottom navigation.
class AppBottomNavigationItem {
  const AppBottomNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Premium Material 3 bottom navigation bar with animated selection.
class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppBottomNavigationItem> destinations;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        boxShadow: AppShadows.elevated,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          top: false,
          minimum: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            height: 68,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            animationDuration: const Duration(milliseconds: 280),
            destinations: [
              for (int i = 0; i < destinations.length; i++)
                NavigationDestination(
                  icon: _AnimatedNavIcon(
                    isSelected: currentIndex == i,
                    child: Icon(destinations[i].icon, size: 24),
                  ),
                  selectedIcon: _AnimatedNavIcon(
                    isSelected: true,
                    child: Icon(destinations[i].selectedIcon, size: 26),
                  ),
                  label: destinations[i].label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Adds a spring-like scale transition to the selected navigation icon.
class _AnimatedNavIcon extends StatelessWidget {
  const _AnimatedNavIcon({required this.isSelected, required this.child});

  final bool isSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.0 : 0.9,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: isSelected ? 1 : 0.72,
        duration: const Duration(milliseconds: 180),
        child: child,
      ),
    );
  }
}
