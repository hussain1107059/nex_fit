import '../entities/dashboard_data.dart';

/// Contract for aggregating the data shown on the premium home dashboard.
abstract interface class DashboardRepository {
  Future<DashboardData> loadDashboard(String userId, DateTime now);
}
