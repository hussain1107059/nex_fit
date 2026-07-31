import '../entities/dashboard_data.dart';

/// Contract for the dashboard's global search across the user's data.
abstract interface class GlobalSearchRepository {
  Future<List<GlobalSearchResult>> search(String userId, String query);
}
