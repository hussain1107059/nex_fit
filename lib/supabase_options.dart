/// Build-time Supabase configuration injected with `--dart-define`.
///
/// ```
/// flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///             --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
/// ```
///
/// Supabase is optional: when the values are missing the app still runs fully
/// offline. Every Supabase-backed feature must check `isConfigured` first.
abstract final class SupabaseOptions {
  static const String _url = String.fromEnvironment('SUPABASE_URL');
  static const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => _url.isNotEmpty && _anonKey.isNotEmpty;

  static String get url => _url;

  static String get anonKey => _anonKey;
}
