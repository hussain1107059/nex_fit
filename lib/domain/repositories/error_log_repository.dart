import '../entities/error_log.dart';

/// Contract for persisting structured error records.
abstract interface class ErrorLogRepository {
  Future<int> insert(ErrorLog log);

  Future<List<ErrorLog>> getRecent({String? userId, int limit});

  Future<int> count({String? userId});

  Future<void> deleteOlderThan(DateTime threshold);
}
