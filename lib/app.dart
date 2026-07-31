import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'l10n/app_localizations.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/router/app_router.dart';

/// Root application widget.
class NexFitApp extends ConsumerWidget {
  const NexFitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final Locale locale = ref.watch(localeProvider);
    final GoRouter router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'NexFit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    );
  }
}
