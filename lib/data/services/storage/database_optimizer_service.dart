import 'package:logging/logging.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/repositories/error_log_repository.dart';
import '../../../domain/repositories/session_repository.dart';
import '../../../domain/repositories/sync_event_repository.dart';
import '../../datasources/local/app_database.dart';
import 'settings_storage_service.dart';

/// A breakdown of the last maintenance run.
class MaintenanceReport {
  const MaintenanceReport({
    this.optimized = false,
    this.vacuumed = false,
    this.cacheCleared = false,
    this.syncEventsPruned = 0,
    this.errorLogsPruned = 0,
    this.sessionsPruned = 0,
    this.completedAt,
  });

  final bool optimized;
  final bool vacuumed;
  final bool cacheCleared;
  final int syncEventsPruned;
  final int errorLogsPruned;
  final int sessionsPruned;
  final DateTime? completedAt;

  MaintenanceReport copyWith({
    bool? optimized,
    bool? vacuumed,
    bool? cacheCleared,
    int? syncEventsPruned,
    int? errorLogsPruned,
    int? sessionsPruned,
    DateTime? completedAt,
  }) {
    return MaintenanceReport(
      optimized: optimized ?? this.optimized,
      vacuumed: vacuumed ?? this.vacuumed,
      cacheCleared: cacheCleared ?? this.cacheCleared,
      syncEventsPruned: syncEventsPruned ?? this.syncEventsPruned,
      errorLogsPruned: errorLogsPruned ?? this.errorLogsPruned,
      sessionsPruned: sessionsPruned ?? this.sessionsPruned,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Background database maintenance: index tuning, vacuum, cache cleanup and
/// log pruning.
///
/// Drives [AppDatabase.optimize], clears the profile-photo cache and prunes
/// old completed sync events, error logs and inactive sessions. Every step is
/// best-effort so a single failure never aborts the run.
class DatabaseOptimizerService {
  DatabaseOptimizerService({
    required this.database,
    required this.storageService,
    required this.syncEventRepository,
    required this.errorLogRepository,
    required this.sessionRepository,
    Logger? logger,
  }) : _logger = logger ?? Logger('DatabaseOptimizerService');

  final AppDatabase database;
  final SettingsStorageService storageService;
  final SyncEventRepository syncEventRepository;
  final ErrorLogRepository errorLogRepository;
  final SessionRepository sessionRepository;
  final Logger _logger;

  /// Runs the full maintenance pass and returns a report of what happened.
  Future<MaintenanceReport> runMaintenance() async {
    MaintenanceReport report = const MaintenanceReport();

    try {
      await database.optimize();
      report = report.copyWith(optimized: true);
    } catch (error, stackTrace) {
      _logger.warning('Optimize failed: $error\n$stackTrace');
    }

    try {
      await storageService.clearPhotoCache();
      report = report.copyWith(cacheCleared: true);
    } catch (error, stackTrace) {
      _logger.warning('Cache cleanup failed: $error\n$stackTrace');
    }

    final DateTime threshold = DateTime.now();

    try {
      await syncEventRepository.deleteCompletedOlderThanAll(
        threshold.subtract(AppConstants.syncEventRetention),
      );
      report = report.copyWith(syncEventsPruned: 1);
    } catch (error, stackTrace) {
      _logger.warning('Sync event pruning failed: $error\n$stackTrace');
    }

    try {
      await errorLogRepository.deleteOlderThan(
        threshold.subtract(AppConstants.errorLogRetention),
      );
      report = report.copyWith(errorLogsPruned: 1);
    } catch (error, stackTrace) {
      _logger.warning('Error log pruning failed: $error\n$stackTrace');
    }

    try {
      await sessionRepository.deleteInactiveOlderThan(
        threshold.subtract(AppConstants.sessionRetention),
      );
      report = report.copyWith(sessionsPruned: 1);
    } catch (error, stackTrace) {
      _logger.warning('Session pruning failed: $error\n$stackTrace');
    }

    _logger.info('Maintenance run finished');
    return report.copyWith(completedAt: DateTime.now());
  }
}
