import 'package:flutter/services.dart' show rootBundle;

/// Supabase configuration.
///
/// Values are injected at build time with `--dart-define`:
///
/// ```
/// flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///             --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
/// ```
///
/// When the defines are missing, the bundled `.env` asset is loaded at runtime
/// (see [loadFromAsset]) so a plain `flutter run` still reaches Supabase.
/// Define values always win over the asset. Supabase is optional: when no
/// configuration is available the app still runs fully offline, and every
/// Supabase-backed feature checks `isConfigured` first.
abstract final class SupabaseOptions {
  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String? _url;
  static String? _anonKey;
  static bool _loadAttempted = false;

  static bool get isConfigured {
    if (_url != null && _url!.isNotEmpty && _anonKey != null && _anonKey!.isNotEmpty) {
      return true;
    }
    return _envUrl.isNotEmpty && _envAnonKey.isNotEmpty;
  }

  static String get url => _url ?? _envUrl;

  static String get anonKey => _anonKey ?? _envAnonKey;

  /// Loads `SUPABASE_URL` / `SUPABASE_ANON_KEY` from the bundled `.env` asset
  /// so the app works when launched without `--dart-define` flags. Best-effort
  /// and idempotent: a missing/unreadable file (or a fresh clone that has no
  /// `.env` yet) leaves the app in offline mode instead of throwing.
  static Future<void> loadFromAsset() async {
    if (_loadAttempted) return;
    _loadAttempted = true;
    // Define-provided configuration wins; nothing to do.
    if (_envUrl.isNotEmpty && _envAnonKey.isNotEmpty) return;

    try {
      final String content = await rootBundle.loadString('.env');
      final Map<String, String> values = _parseEnv(content);
      final String? url = values['SUPABASE_URL'];
      final String? anonKey = values['SUPABASE_ANON_KEY'];
      if (url != null && url.isNotEmpty && anonKey != null && anonKey.isNotEmpty) {
        _url = url;
        _anonKey = anonKey;
      }
    } catch (_) {
      // No .env bundled: stay offline. Supabase-backed features gate on
      // isConfigured and fail gracefully.
    }
  }

  static Map<String, String> _parseEnv(String content) {
    final Map<String, String> values = <String, String>{};
    for (final String rawLine in content.split('\n')) {
      final String line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final int eq = line.indexOf('=');
      if (eq <= 0) continue;
      final String key = line.substring(0, eq).trim();
      final String value = line.substring(eq + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      values[key] = value;
    }
    return values;
  }
}
