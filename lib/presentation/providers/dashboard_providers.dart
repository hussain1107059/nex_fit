import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/dashboard_data.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';

/// Index of the currently selected tab inside the app shell.
final shellTabIndexProvider = StateProvider<int>((ref) => 0);

/// Loads and refreshes the premium home dashboard aggregate.
class DashboardController extends AsyncNotifier<DashboardData> {
  @override
  Future<DashboardData> build() {
    return _load();
  }

  Future<DashboardData> _load() async {
    final AppUser? user = ref.watch(currentUserProvider);
    if (user == null || !user.isSignedIn) {
      throw StateError('Dashboard requires a signed-in user');
    }
    return ref.watch(dashboardRepositoryProvider).loadDashboard(
          user.id,
          DateTime.now(),
        );
  }

  /// Re-runs the aggregation so the screen reflects new database entries.
  Future<void> refresh() async {
    state = AsyncValue<DashboardData>.loading().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardData>(
      DashboardController.new,
    );

/// Text currently typed in the dashboard global search field.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Live global search results across workouts, exercises, foods and meals.
final searchResultsProvider =
    FutureProvider.autoDispose<List<GlobalSearchResult>>((ref) async {
      final String query = ref.watch(searchQueryProvider);
      if (query.trim().isEmpty) return const <GlobalSearchResult>[];
      final AppUser? user = ref.watch(currentUserProvider);
      if (user == null || !user.isSignedIn) return const <GlobalSearchResult>[];
      return ref.watch(globalSearchRepositoryProvider).search(user.id, query);
    });
