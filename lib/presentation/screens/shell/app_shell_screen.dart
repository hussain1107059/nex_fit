import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/layout/app_bottom_navigation_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/dashboard_providers.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../workout/workout_screen.dart';
import 'module_placeholder_screen.dart';

/// Root scaffold hosting the five-module bottom navigation.
class AppShellScreen extends ConsumerStatefulWidget {
  const AppShellScreen({super.key});

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  DateTime? _lastBackPress;

  void _handleBackPressed() {
    final DateTime now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    AppSnackbar.info(context, context.l10n.exitAppHint);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(connectivityProvider);
    final int currentIndex = ref.watch(shellTabIndexProvider);
    final AppLocalizations l10n = context.l10n;

    final List<Widget> screens = <Widget>[
      const DashboardScreen(),
      const WorkoutScreen(),
      ModulePlaceholderScreen(
        title: l10n.tabProgress,
        icon: AppAssets.homeIcon,
        subtitle: l10n.moduleProgressSubtitle,
      ),
      ModulePlaceholderScreen(
        title: l10n.tabNutrition,
        icon: AppAssets.dietIcon,
        subtitle: l10n.moduleNutritionSubtitle,
      ),
      const ProfileScreen(),
    ];

    final List<AppBottomNavigationItem> destinations =
        <AppBottomNavigationItem>[
          AppBottomNavigationItem(
            label: l10n.tabHome,
            icon: Icons.home_rounded,
            selectedIcon: Icons.home_rounded,
          ),
          AppBottomNavigationItem(
            label: l10n.tabWorkout,
            icon: Icons.fitness_center_rounded,
            selectedIcon: Icons.fitness_center_rounded,
          ),
          AppBottomNavigationItem(
            label: l10n.tabProgress,
            icon: Icons.trending_up_rounded,
            selectedIcon: Icons.trending_up_rounded,
          ),
          AppBottomNavigationItem(
            label: l10n.tabNutrition,
            icon: Icons.restaurant_rounded,
            selectedIcon: Icons.restaurant_rounded,
          ),
          AppBottomNavigationItem(
            label: l10n.tabProfile,
            icon: Icons.person_rounded,
            selectedIcon: Icons.person_rounded,
          ),
        ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        body: IndexedStack(index: currentIndex, children: screens),
        bottomNavigationBar: AppBottomNavigationBar(
          currentIndex: currentIndex,
          destinations: destinations,
          onDestinationSelected: (int index) {
            ref.read(shellTabIndexProvider.notifier).state = index;
          },
        ),
      ),
    );
  }
}
