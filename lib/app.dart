import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'data/services/security/session_manager.dart';
import 'domain/entities/app_settings.dart';
import 'domain/entities/app_user.dart';
import 'domain/entities/common_enums.dart';
import 'injection/dependency_injection.dart';
import 'l10n/app_localizations.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/providers/settings_providers.dart';
import 'presentation/router/app_router.dart';
import 'presentation/screens/settings/lock_screen.dart';

/// Root application widget.
///
/// Owns the resolved theme (system / light / dark / AMOLED, with optional
/// Material You dynamic colour), the global font scale and the app-lock gate.
class NexFitApp extends ConsumerStatefulWidget {
  const NexFitApp({super.key});

  @override
  ConsumerState<NexFitApp> createState() => _NexFitAppState();
}

class _NexFitAppState extends ConsumerState<NexFitApp>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _backgroundedAt = DateTime.now();
      case AppLifecycleState.resumed:
        _handleResume();
    }
  }

  Future<void> _handleResume() async {
    final DateTime? backgrounded = _backgroundedAt;
    _backgroundedAt = null;

    // Keep the secure session alive: slide the expiry window whenever the app
    // returns to the foreground.
    final AppUser? user = ref.read(currentUserProvider);
    if (user?.isSignedIn == true) {
      final SessionManager session = ref.read(sessionManagerProvider);
      final Duration timeout = Duration(
        minutes:
            ref.read(settingsControllerProvider).valueOrNull?.sessionTimeoutMinutes ??
            30,
      );
      unawaited(session.touch(user!.id, timeout: timeout));
    }

    final AppSettings? settings =
        ref.read(settingsControllerProvider).valueOrNull;
    if (settings == null || !settings.appLockEnabled) return;

    final Duration elapsed = backgrounded == null
        ? Duration.zero
        : DateTime.now().difference(backgrounded);
    final bool requiresLock = settings.autoLock == AutoLockDelay.immediately ||
        elapsed >= settings.autoLock.duration;
    if (requiresLock) {
      ref.read(appLockProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = ref.watch(appRouterProvider);

    final AppThemeMode themeMode =
        ref.watch(settingsControllerProvider).valueOrNull?.themeMode ??
        AppThemeMode.system;
    final bool dynamicColor =
        ref.watch(settingsControllerProvider).valueOrNull?.dynamicColor ?? false;
    final FontScale fontScale =
        ref.watch(settingsControllerProvider).valueOrNull?.fontScale ??
        FontScale.medium;

    final ThemeMode resolvedMode = switch (themeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark || AppThemeMode.amoled => ThemeMode.dark,
    };
    final ThemeData darkTheme = switch (themeMode) {
      AppThemeMode.amoled => AppTheme.amoled,
      _ => AppTheme.dark,
    };

    Widget buildApp(ThemeData light, ThemeData dark) {
      return MaterialApp.router(
        title: 'NexFit',
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: dark,
        themeMode: resolvedMode,
        locale: ref.watch(localeProvider),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
        builder: (BuildContext context, Widget? child) {
          return _AppDecorators(
            fontScale: fontScale,
            child: child ?? const SizedBox.shrink(),
          );
        },
      );
    }

    if (dynamicColor) {
      return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          final ThemeData light = lightDynamic == null
              ? AppTheme.light
              : AppTheme.fromColorScheme(lightDynamic);
          final ThemeData dark = darkDynamic == null
              ? AppTheme.dark
              : AppTheme.fromColorScheme(darkDynamic);
          return buildApp(light, dark);
        },
      );
    }

    return buildApp(AppTheme.light, darkTheme);
  }
}

/// Applies the selected font scale and the app-lock overlay above the routed
/// content. Runs below [MaterialApp]'s Theme/Localizations so lookups work.
class _AppDecorators extends StatelessWidget {
  const _AppDecorators({required this.fontScale, required this.child});

  final FontScale fontScale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(fontScale.scale),
      ),
      child: _AppLockGate(child: child),
    );
  }
}

class _AppLockGate extends ConsumerWidget {
  const _AppLockGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool locked = ref.watch(appLockProvider);
    if (!locked) return child;
    return const LockScreen();
  }
}
