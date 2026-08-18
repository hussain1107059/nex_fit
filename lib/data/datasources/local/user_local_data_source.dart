import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/app_user.dart';
import '../../models/local_user_model.dart';
import 'app_database.dart';

/// Local SQLite data source for user profiles.
class UserLocalDataSource {
  UserLocalDataSource({
    required this._database,
    Logger? logger,
  }) : _logger = logger ?? Logger('UserLocalDataSource');

  final AppDatabase _database;
  final Logger _logger;

  Future<Database> get _db async => _database.database;

  Future<void> saveProfile(AppUser user) async {
    try {
      final Database db = await _db;
      final Map<String, Object?> map = LocalUserModel.toMap(user);
      final String columns = map.keys.join(', ');
      final String placeholders = map.keys.map((_) => '?').join(', ');
      final String updates = map.keys
          .map((String key) => '$key = excluded.$key')
          .join(', ');
      // UPSERT (ON CONFLICT DO UPDATE) mutates the existing row in place.
      // ConflictAlgorithm.replace would DELETE + re-INSERT the users row and,
      // with PRAGMA foreign_keys = ON, cascade-delete every child row (weight
      // logs, workouts, ...) on each re-login.
      await db.rawInsert(
        'INSERT INTO ${LocalUserModel.table} ($columns) '
        'VALUES ($placeholders) '
        'ON CONFLICT(id) DO UPDATE SET $updates',
        map.values.toList(),
      );
    } catch (error, stackTrace) {
      _logger.severe('Failed to save user profile: $error', error, stackTrace);
      throw const DatabaseException('errorDatabase', code: 'save_profile');
    }
  }

  Future<AppUser?> getProfile(String uid) async {
    try {
      final Database db = await _db;
      final List<Map<String, Object?>> rows = await db.query(
        LocalUserModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[uid],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return LocalUserModel.fromMap(rows.first);
    } catch (error, stackTrace) {
      _logger.severe('Failed to read user profile: $error', error, stackTrace);
      throw const DatabaseException('errorDatabase', code: 'get_profile');
    }
  }

  Future<void> updateLastLogin(String uid) async {
    try {
      final Database db = await _db;
      await db.update(
        LocalUserModel.table,
        <String, Object?>{
          'last_login': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: <Object?>[uid],
      );
    } catch (error, stackTrace) {
      _logger.severe('Failed to update last login: $error', error, stackTrace);
      throw const DatabaseException('errorDatabase', code: 'update_last_login');
    }
  }

  Future<void> deleteProfile(String uid) async {
    try {
      final Database db = await _db;
      await db.delete(
        LocalUserModel.table,
        where: 'id = ?',
        whereArgs: <Object?>[uid],
      );
    } catch (error, stackTrace) {
      _logger.severe('Failed to delete user profile: $error', error, stackTrace);
      throw const DatabaseException('errorDatabase', code: 'delete_profile');
    }
  }
}
