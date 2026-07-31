import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/app_preferences_repository.dart';
import '../../injection/dependency_injection.dart';

/// Riverpod notifier that owns the current [ThemeMode] and persists it.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  AppPreferencesRepository get _repository =>
      ref.read(appPreferencesRepositoryProvider);

  @override
  ThemeMode build() {
    return _repository.getThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _repository.setThemeMode(mode);
  }

  Future<void> toggle() async {
    final ThemeMode next = switch (state) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.system => ThemeMode.dark,
    };
    await setThemeMode(next);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
