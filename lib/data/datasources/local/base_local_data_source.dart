import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../core/errors/app_exception.dart';
import 'app_database.dart';

/// Base class for every SQLite data source (DAO). Exposes the [AppDatabase]
/// connection and wraps unexpected errors into [DatabaseException]s so the
/// domain layer only ever deals with app-level exceptions.
abstract class BaseLocalDataSource {
  BaseLocalDataSource({
    required this._database,
    required String logName,
    Logger? logger,
  }) : _logName = logName,
       _logger = logger ?? Logger(logName);

  final AppDatabase _database;
  final String _logName;
  final Logger _logger;

  /// The underlying [AppDatabase] for advanced transactions.
  AppDatabase get database => _database;

  /// The live SQLite connection, lazily opened on first use.
  Future<Database> get dbConnection => _database.database;

  /// Runs [action] and maps any thrown error to a [DatabaseException]
  /// carrying [code] so callers can react programmatically.
  Future<T> guard<T>(String code, Future<T> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      _logger.severe('$_logName.$code failed: $error', error, stackTrace);
      throw DatabaseException('errorDatabase', code: code);
    }
  }
}
