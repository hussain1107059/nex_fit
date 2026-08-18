import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/release_logger.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/services/auth/google_sign_in_service.dart';
import '../../../data/services/supabase/supabase_service.dart';
import '../../../data/services/security/app_error_logger.dart';
import '../../../data/services/security/encryption_service.dart';
import '../../../data/services/security/session_manager.dart';
import '../../../data/services/sync/incremental_sync_coordinator.dart';
import '../../../data/services/sync/sync_event_recorder.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/security_enums.dart';
import '../../../domain/repositories/app_preferences_repository.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../injection/dependency_injection.dart';
import '../../providers/auth_controller.dart';
import '../../providers/auth_provider.dart';
import '../../providers/incremental_sync_providers.dart';
import '../../providers/reminder_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/water_providers.dart';
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
      final SupabaseService supabase = ref.read(supabaseServiceProvider);
      final GoogleSignInService googleSignIn =
          ref.read(googleSignInServiceProvider);
      final AppDatabase database = ref.read(appDatabaseProvider);

      await Future.wait([
        supabase.initialize(),
        _safeGoogleSignInInit(googleSignIn),
        database.database,
        Future<void>.delayed(AppConstants.splashDuration),
      ]);

      // Pick up any persisted session now that Supabase is ready.
      await ref.read(authControllerProvider.notifier).syncSession();

      // --- Security bootstrap -------------------------------------------
      // Global handlers must be installed before any feature code can throw so
      // every unhandled exception lands in the local error log.
      final AppErrorLogger errorLogger = ref.read(errorLoggerProvider);
      errorLogger.userIdProvider = () => ref.read(currentUserProvider)?.id;
      errorLogger.installGlobalHandlers();

      final AppUser? user = ref.read(currentUserProvider);

      // Load the field-encryption keys and point the sync recorder at the
      // current user so data sources can encrypt and queue events.
      final bool encryptionEnabled =
          ref.read(settingsControllerProvider).valueOrNull?.encryptionEnabled ??
          true;
      await FieldEncryption.configure(
        keyManager: ref.read(keyManagerProvider),
        enabled: encryptionEnabled,
      );
      SyncEventRecorder.configure(
        repository: ref.read(syncEventRepositoryProvider),
        deviceIdProvider: () =>
            ref.read(deviceIdServiceProvider).getOrCreate(),
        activeUserId: user?.isSignedIn == true ? user?.id : null,
      );

      // Validate the secure session. Only a device change (the session was
      // started on another install/device) forces a re-login: it deactivates
      // the local session and clears the Supabase session. A merely expired or
      // absent secure session must NOT log the user out — the Supabase session
      // is the source of truth for "remember me", so re-establish the secure
      // session and continue with auto-login.
      if (user?.isSignedIn == true) {
        final SessionManager sessionManager = ref.read(sessionManagerProvider);
        final Duration timeout = Duration(
          minutes:
              ref.read(settingsControllerProvider).valueOrNull?.sessionTimeoutMinutes ??
              30,
        );
        final SessionStatus status = await sessionManager.validate(
          user!.id,
          timeout: timeout,
        );
        switch (status) {
          case SessionStatus.valid:
            unawaited(sessionManager.touch(user.id, timeout: timeout));
          case SessionStatus.expired:
          case SessionStatus.none:
            // Still authenticated with Supabase; re-issue a fresh secure
            // session so auto-login continues instead of forcing credentials.
            unawaited(sessionManager.startSession(user.id, timeout: timeout));
          case SessionStatus.deviceChanged:
            await sessionManager.endSession(user.id);
            unawaited(ref.read(authControllerProvider.notifier).signOut());
        }
      }

      // Background: recover/integrity, maintenance, reminders and scheduled
      // backup all run after navigation so they never delay first paint.
      unawaited(_runBackgroundTasks(user));
    } catch (error, stackTrace) {
      // A failing service must never leave the app stuck on the splash
      // spinner; log it and let the router guard pick a destination.
      devLog('Splash bootstrap failed: $error', error: error, stackTrace: stackTrace);
    }

    if (!mounted) return;
    // The router redirect sends signed-in users to the correct destination.
    context.go(AppRoutes.login);
  }

  /// Deferred, non-blocking tasks: DB recovery/maintenance, reminder schedule
  /// sync, remember-me handling, the incremental sync on startup and the due
  /// auto-backup.
  Future<void> _runBackgroundTasks(AppUser? user) async {
    try {
      // Check DB integrity (auto-restore latest backup when corrupted) and run
      // a maintenance pass.
      await ref.read(recoveryManagerProvider).checkAndRecover(userId: user?.id);
      unawaited(ref.read(databaseOptimizerServiceProvider).runMaintenance());

      // Activate the incremental-sync hub (Realtime + connectivity listeners)
      // and run the first sync of the session. Missed changes are recovered by
      // the cursor pull (PROMPT 18).
      ref.read(incrementalSyncCoordinatorProvider).requestSync(
            SyncTrigger.startup,
          );

      // Re-sync the hydration reminders with the signed-in user's schedule so
      // notifications survive reboots, app updates and account switches.
      await rescheduleHydrationReminders(ref);

      // Bind notification tap/action callbacks, re-sync the full reminder
      // module schedule (handles timezone changes) and record any occurrences
      // that fired while the app was closed.
      bindReminderNotificationHandler(ref);
      await rescheduleReminders(ref);
      await syncMissedReminders(ref);

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

      // Best-effort: run an automatic Drive backup when it is due (silently
      // skipped when disabled, offline or not signed in).
      await _runScheduledBackupIfDue();
    } catch (error, stackTrace) {
      devLog('Background bootstrap task failed: $error', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _safeGoogleSignInInit(GoogleSignInService service) async {
    try {
      await service.initialize();
    } catch (error, stackTrace) {
      devLog('Google Sign-In initialization failed: $error', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _runScheduledBackupIfDue() async {
    final user = ref.read(currentUserProvider);
    if (user == null || !user.isSignedIn) return;
    try {
      final GoogleSignInService signIn =
          ref.read(googleSignInServiceProvider);
      await signIn.attemptSilentSignIn();
      await ref
          .read(backupServiceProvider)
          .runAutoBackupIfDue(userId: user.id);
    } catch (error, stackTrace) {
      devLog('Scheduled backup check failed: $error', error: error, stackTrace: stackTrace);
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
                    child: Image.asset(
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
