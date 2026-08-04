import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/services/storage/profile_photo_service.dart';

/// Renders the profile picture from a locally stored file, a web cache
/// entry, a remote URL or (as a fallback) the user's initials.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    this.photoPath,
    this.networkUrl,
    this.name,
    this.email,
    this.radius = 44,
    this.showRing = true,
    this.onTap,
  });

  final String? photoPath;
  final String? networkUrl;
  final String? name;
  final String? email;
  final double radius;
  final bool showRing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final Widget image = _resolveImage(context);

    final Widget avatar = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _brandGradient(context),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: showRing ? const EdgeInsets.all(3) : EdgeInsets.zero,
      child: ClipOval(child: image),
    );

    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }

  List<Color> _brandGradient(BuildContext context) {
    final AppColors colors =
        AppColors.light;
    return colors.brandGradient;
  }

  Widget _resolveImage(BuildContext context) {
    // Resolve at the rendered size so large source images are downscaled in
    // the cache instead of being decoded and kept at full resolution.
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final int cacheSide = (radius * 2 * dpr).round();

    final String? path = photoPath;
    if (path != null && path.isNotEmpty) {
      if (kIsWeb) {
        final Uint8List? bytes = ProfilePhotoService.webBytesFor(path);
        if (bytes != null) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            cacheWidth: cacheSide,
            cacheHeight: cacheSide,
          );
        }
      } else {
        final File file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: cacheSide,
            cacheHeight: cacheSide,
            errorBuilder: (_, _, _) => _fallback(context),
          );
        }
      }
    }

    final String? url = networkUrl;
    if (url != null && url.isNotEmpty && url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: cacheSide,
        cacheHeight: cacheSide,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    }

    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final String source = (name?.trim().isNotEmpty ?? false)
        ? name!.trim()
        : (email ?? '?');
    final String initial = source.isEmpty ? '?' : source[0].toUpperCase();

    return Container(
      color: scheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: context.textTheme.headlineMedium?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
