import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../injection/dependency_injection.dart';
import '../../domain/repositories/app_preferences_repository.dart';

/// Owns the active [Locale] and persists the user's language choice.
class LocaleNotifier extends Notifier<Locale> {
  AppPreferencesRepository get _repository =>
      ref.read(appPreferencesRepositoryProvider);

  @override
  Locale build() {
    final String? stored = _repository.getLocale();
    return Locale(stored ?? AppConstants.defaultLocale);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _repository.setLocale(locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
