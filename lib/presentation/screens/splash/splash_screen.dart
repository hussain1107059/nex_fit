import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/services/auth/google_sign_in_service.dart';
import '../../../data/services/firebase_service.dart';
import '../../../domain/repositories/app_preferences_repository.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../injection/dependency_injection.dart';
import '../../providers/auth_controller.dart';
import '../../router/app_router.dart';

/// Entry screen shown while the app bootstraps its services.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final FirebaseService firebase = ref.read(firebaseServiceProvider);
      final GoogleSignInService googleSignIn =
          ref.read(googleSignInServiceProvider);
      final AppDatabase database = ref.read(appDatabaseProvider);

      await Future.wait([
        firebase.initialize(),
        _safeGoogleSignInInit(googleSignIn),
        database.database,
        Future<void>.delayed(AppConstants.splashDuration),
      ]);

      // Pick up any persisted session now that Firebase is ready.
      await ref.read(authControllerProvider.notifier).syncSession();

      // Honor "remember me": when the user opted out, drop the persisted
      // session so the login screen is shown on the next launch.
      final AppPreferencesRepository preferences =
          ref.read(appPreferencesRepositoryProvider);
      if (!preferences.getRememberMe()) {
        final AuthRepository auth = ref.read(authRepositoryProvider);
        if (auth.currentUser.isSignedIn) {
          await ref.read(authControllerProvider.notifier).signOut();
        }
      }
    } catch (error, stackTrace) {
      // A failing service must never leave the app stuck on the splash
      // spinner; log it and let the router guard pick a destination.
      debugPrint('Splash bootstrap failed: $error\n$stackTrace');
    }

    if (!mounted) return;
    // The router redirect sends signed-in users to the correct destination.
    context.go(AppRoutes.login);
  }

  Future<void> _safeGoogleSignInInit(GoogleSignInService service) async {
    try {
      await service.initialize();
    } catch (error, stackTrace) {
      debugPrint('Google Sign-In initialization failed: $error\n$stackTrace');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surface,
              scheme.surface,
              scheme.primaryContainer.withValues(alpha: 0.35),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.3),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: SvgPicture.asset(
                      AppAssets.logo,
                      fit: BoxFit.cover,
                    ),
                  ),
                  AppSpacing.xxl.heightSpace,
                  Text(
                    AppConstants.appName,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  AppSpacing.xs.heightSpace,
                  Text(
                    context.l10n.appTagline,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  AppSpacing.xxxl.heightSpace,
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: scheme.primary,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
