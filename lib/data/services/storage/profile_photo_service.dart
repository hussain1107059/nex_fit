import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Picks, compresses and stores the user's profile photo fully offline.
///
/// Photos are stored as compressed JPEGs inside the app's documents
/// directory and referenced by an absolute path in the `user_profile` table,
/// so they survive restarts and are included whenever the database is backed
/// up. On the web (where `dart:io` is unavailable) the picked bytes are kept
/// in an in-memory cache and the cache key is persisted instead.
class ProfilePhotoService {
  ProfilePhotoService({Logger? logger})
    : _logger = logger ?? Logger('ProfilePhotoService');

  final Logger _logger;

  /// In-memory photo cache used on web platforms only.
  static final Map<String, Uint8List> _webCache = <String, Uint8List>{};

  /// Opens the system gallery or camera picker.
  Future<XFile?> pick(ImageSource source) {
    return ImagePicker().pickImage(source: source);
  }

  /// Picks an image, compresses it and persists it for [userId].
  ///
  /// Returns the stored path (or a web cache key), or null when the picker
  /// is cancelled. The previous photo file for the same user is removed.
  Future<String?> saveForUser({
    required String userId,
    ImageSource source = ImageSource.gallery,
  }) async {
    final XFile? file = await pick(source);
    if (file == null) return null;
    return storeForUser(userId: userId, file: file);
  }

  /// Compresses and persists an already-picked [file] for [userId].
  Future<String?> storeForUser({
    required String userId,
    required XFile file,
  }) async {
    final Uint8List bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;

    if (kIsWeb) {
      final String key = 'profile_photo_$userId';
      _webCache[key] = bytes;
      return key;
    }

    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory photoDir = Directory(
      path.join(documents.path, 'profile_photos'),
    );
    await photoDir.create(recursive: true);
    final String targetPath = path.join(
      photoDir.path,
      '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    try {
      final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: 82,
        format: CompressFormat.jpeg,
        minWidth: 720,
        minHeight: 720,
      );
      if (compressed != null && await File(compressed.path).exists()) {
        return compressed.path;
      }
    } catch (error, stackTrace) {
      _logger.warning(
        'Profile photo compression failed, storing original: $error\n$stackTrace',
      );
    }

    await File(targetPath).writeAsBytes(bytes, flush: true);
    return targetPath;
  }

  /// Deletes a stored profile photo file (native) or cache entry (web).
  Future<void> deletePhoto(String? photoPath) async {
    if (photoPath == null || photoPath.isEmpty) return;
    if (kIsWeb) {
      _webCache.remove(photoPath);
      return;
    }
    try {
      final File file = File(photoPath);
      if (await file.exists()) await file.delete();
    } catch (error, stackTrace) {
      _logger.warning('Failed to delete profile photo: $error\n$stackTrace');
    }
  }

  /// Bytes backing a web-cached profile photo, or null.
  static Uint8List? webBytesFor(String photoPath) => _webCache[photoPath];
}
