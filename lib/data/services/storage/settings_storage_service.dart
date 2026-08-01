import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show Database;

import '../../datasources/local/app_database.dart';
import 'profile_photo_service.dart';

/// Size statistics for a single cache folder.
class CacheStats {
  const CacheStats({required this.bytes, required this.fileCount});

  final int bytes;
  final int fileCount;
}

/// Offline storage maintenance: reports database/cache sizes and performs the
/// clear-cache, optimize and export operations exposed in the Storage settings.
class SettingsStorageService {
  SettingsStorageService({
    required this.database,
    Logger? logger,
  }) : _logger = logger ?? Logger('SettingsStorageService');

  final AppDatabase database;
  final Logger _logger;

  /// Size of the SQLite database file in bytes.
  Future<int> databaseSizeBytes() async {
    try {
      final File file = File(await database.databaseFilePath);
      if (await file.exists()) return await file.length();
    } catch (error, stackTrace) {
      _logger.warning('Could not read database size: $error\n$stackTrace');
    }
    return 0;
  }

  /// Size of the profile-photo cache in bytes.
  Future<int> imageCacheSizeBytes() async {
    final CacheStats stats = await imageCacheStats();
    return stats.bytes;
  }

  Future<CacheStats> imageCacheStats() async {
    if (kIsWeb) return const CacheStats(bytes: 0, fileCount: 0);
    try {
      final Directory documents = await getApplicationDocumentsDirectory();
      final Directory dir = Directory(
        path.join(documents.path, 'profile_photos'),
      );
      if (!await dir.exists()) return const CacheStats(bytes: 0, fileCount: 0);
      int bytes = 0;
      int count = 0;
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is File) {
          try {
            bytes += await entity.length();
            count++;
          } catch (_) {}
        }
      }
      return CacheStats(bytes: bytes, fileCount: count);
    } catch (error, stackTrace) {
      _logger.warning('Could not scan image cache: $error\n$stackTrace');
      return const CacheStats(bytes: 0, fileCount: 0);
    }
  }

  /// Deletes every cached profile photo on disk.
  Future<void> clearImageCache() async {
    if (kIsWeb) return;
    try {
      final Directory documents = await getApplicationDocumentsDirectory();
      final Directory dir = Directory(
        path.join(documents.path, 'profile_photos'),
      );
      if (!await dir.exists()) return;
      await for (final FileSystemEntity entity in dir.list()) {
        try {
          if (entity is File) await entity.delete();
        } catch (_) {}
      }
    } catch (error, stackTrace) {
      _logger.warning('Could not clear image cache: $error\n$stackTrace');
    }
  }

  /// Runs SQLite maintenance (PRAGMA optimize + VACUUM on native).
  Future<void> optimizeDatabase() => database.optimize();

  /// Exports a copy of the SQLite database to the app's documents directory.
  /// Returns the exported file path, or null when not supported (web).
  Future<String?> exportDatabase() async {
    if (kIsWeb) return null;
    try {
      final File source = File(await database.databaseFilePath);
      if (!await source.exists()) return null;
      final Directory documents = await getApplicationDocumentsDirectory();
      final String name =
          'nexfit_backup_${DateTime.now().millisecondsSinceEpoch}.db';
      final File target = File(path.join(documents.path, name));
      await source.copy(target.path);
      return target.path;
    } catch (error, stackTrace) {
      _logger.warning('Could not export database: $error\n$stackTrace');
      return null;
    }
  }

  /// Produces a consistent snapshot of the current SQLite database as bytes.
  /// Uses `VACUUM INTO` when available and falls back to a plain file copy.
  /// Returns null on web or when the snapshot could not be created.
  Future<Uint8List?> createSnapshotBytes() async {
    if (kIsWeb) return null;
    final String dbPath = await database.databaseFileRawPath;
    final Directory documents = await getApplicationDocumentsDirectory();
    final String tmpPath = path.join(
      documents.path,
      'nexfit_snapshot_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    try {
      final Database db = await database.database;
      try {
        await db.execute("VACUUM INTO '$tmpPath'");
      } catch (_) {
        final File source = File(dbPath);
        if (await source.exists()) await source.copy(tmpPath);
      }
      final File tmp = File(tmpPath);
      if (await tmp.exists()) {
        final Uint8List bytes = await tmp.readAsBytes();
        await tmp.delete();
        return bytes;
      }
    } catch (error, stackTrace) {
      _logger.warning('Could not snapshot database: $error\n$stackTrace');
    }
    return null;
  }

  /// Deletes every cached photo through the photo service (keeps the web
  /// cache in sync with the on-disk cache).
  Future<void> clearPhotoCache() async {
    if (!kIsWeb) {
      await clearImageCache();
    }
    ProfilePhotoService.clearWebCache();
  }
}
