import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../supabase/supabase_service.dart';

/// Picks, compresses and stores the user's profile photo.
///
/// When Supabase is available the compressed image is uploaded to the public
/// `avatars` storage bucket and the returned public URL is persisted in
/// `user_profile.photo_path` (which the sync layer mirrors to
/// `profiles.avatar_url`), so the photo displays on every device. When
/// Supabase is not configured or the upload fails, the image falls back to a
/// local file path (or an in-memory web cache key) exactly like before, so
/// offline-first users are never blocked. Legacy local paths remain readable.
class ProfilePhotoService {
  ProfilePhotoService({this.supabaseService, Logger? logger})
    : _logger = logger ?? Logger('ProfilePhotoService');

  static const String bucket = 'avatars';

  final SupabaseService? supabaseService;
  final Logger _logger;

  /// In-memory photo cache used on web platforms only (legacy fallback).
  static final Map<String, Uint8List> _webCache = <String, Uint8List>{};

  /// Opens the system gallery or camera picker.
  Future<XFile?> pick(ImageSource source) {
    return ImagePicker().pickImage(source: source);
  }

  /// Picks an image, compresses it and uploads it for [userId].
  ///
  /// Returns the stored public URL (or a local path / web cache key when
  /// offline), or null when the picker is cancelled.
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

    final SupabaseService? service = supabaseService;
    final supabase.SupabaseClient? client =
        service != null && service.isReady ? service.client : null;

    Uint8List uploadBytes = bytes;
    if (!kIsWeb) {
      final Uint8List? compressed = await _compress(bytes);
      if (compressed != null) uploadBytes = compressed;
    }

    if (client == null) {
      return _storeLocal(userId: userId, bytes: uploadBytes);
    }

    final String objectName =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await client.storage.from(bucket).uploadBinary(
        objectName,
        uploadBytes,
        fileOptions: const supabase.FileOptions(contentType: 'image/jpeg'),
      );
    } catch (error, stackTrace) {
      _logger.warning(
        'Avatar upload failed, storing locally: $error',
        error,
        stackTrace,
      );
      return _storeLocal(userId: userId, bytes: uploadBytes);
    }
    return client.storage.from(bucket).getPublicUrl(objectName);
  }

  /// Deletes a stored profile photo: the remote storage object (when the
  /// value is a public URL) and the local file / web cache entry.
  Future<void> deletePhoto(String? photoPath) async {
    if (photoPath == null || photoPath.isEmpty) return;
    if (kIsWeb) _webCache.remove(photoPath);

    final String? objectPath = _objectPathFromUrl(photoPath);
    final SupabaseService? service = supabaseService;
    final supabase.SupabaseClient? client =
        service != null && service.isReady ? service.client : null;

    if (objectPath != null && client != null) {
      try {
        await client.storage.from(bucket).remove(<String>[objectPath]);
        return;
      } catch (error, stackTrace) {
        _logger.warning(
          'Failed to remove remote avatar: $error',
          error,
          stackTrace,
        );
      }
    }

    if (!kIsWeb && objectPath == null) {
      try {
        final File file = File(photoPath);
        if (await file.exists()) await file.delete();
      } catch (error, stackTrace) {
        _logger.warning('Failed to delete profile photo: $error', error, stackTrace);
      }
    }
  }

  /// Compresses [bytes] to a ~720px JPEG, or returns null when the native
  /// codec is unavailable.
  Future<Uint8List?> _compress(Uint8List bytes) async {
    try {
      final Uint8List output = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 82,
        format: CompressFormat.jpeg,
        minWidth: 720,
        minHeight: 720,
      );
      return output.isEmpty ? null : output;
    } catch (error, stackTrace) {
      _logger.warning(
        'Profile photo compression failed: $error',
        error,
        stackTrace,
      );
      return null;
    }
  }

  /// Stores [bytes] fully offline: a local file on native, a memory cache
  /// entry on the web.
  Future<String?> _storeLocal({
    required String userId,
    required Uint8List bytes,
  }) async {
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
    await File(targetPath).writeAsBytes(bytes, flush: true);
    return targetPath;
  }

  /// Extracts the in-bucket object path from a public avatar URL, or null
  /// when [value] is not a storage URL (e.g. a legacy local file path).
  String? _objectPathFromUrl(String value) {
    final Uri? uri = Uri.tryParse(value);
    if (uri == null) return null;
    const String marker = '/object/public/$bucket/';
    final int index = uri.path.indexOf(marker);
    if (index < 0) return null;
    return uri.path.substring(index + marker.length);
  }

  /// Bytes backing a web-cached profile photo, or null.
  static Uint8List? webBytesFor(String photoPath) => _webCache[photoPath];

  /// Clears the in-memory photo cache (used by the storage settings screen).
  static void clearWebCache() => _webCache.clear();
}