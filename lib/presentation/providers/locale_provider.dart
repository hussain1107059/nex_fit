import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/extensions/string_extensions.dart';
import '../../injection/dependency_injection.dart';
import '../../domain/repositories/app_preferences_repository.dart';

/// Owns the active [Locale] and persists the user's language choice.
class LocaleNotifier extends Notifier<Locale> {
  AppPreferencesRepository get _repository =>
      ref.read(appPreferencesRepositoryProvider);

  @override
  Locale build() {
    final String? stored = _repository.getLocale();
    final Locale locale = Locale(stored ?? AppConstants.defaultLocale);
    DigitLocale.currentLanguageCode = locale.languageCode;
    return locale;
  }

  Future<void> setLocale(Locale locale) async {
    DigitLocale.currentLanguageCode = locale.languageCode;
    state = locale;
    await _repository.setLocale(locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
