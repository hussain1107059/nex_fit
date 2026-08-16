import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../supabase_options.dart';
import 'secure_local_storage.dart';

/// Owns the Supabase lifecycle for the app.
///
/// Supabase is optional: when build-time configuration is missing the app
/// still runs fully offline. Every Supabase-backed feature must call [isReady]
/// before use.
class SupabaseService {
  SupabaseService({Logger? logger})
      : _logger = logger ?? Logger('SupabaseService');

  final Logger _logger;

  bool _initialized = false;
  supabase.SupabaseClient? _client;

  bool get isReady => _initialized;

  /// The active [supabase.SupabaseClient], or null before [initialize]
  /// succeeds. Always check [isReady] first.
  supabase.SupabaseClient? get client => _client;

  Future<bool> initialize() async {
    if (_initialized) return true;

    if (!SupabaseOptions.isConfigured) {
      _logger.info('Supabase configuration not provided. Running offline.');
      return false;
    }

    try {
      await supabase.Supabase.initialize(
        url: SupabaseOptions.url,
        publishableKey: SupabaseOptions.anonKey,
        // Persist the session in the OS keychain, not plaintext
        // SharedPreferences, so the access/refresh tokens are not readable by
        // anyone who extracts app data.
        authOptions: supabase.FlutterAuthClientOptions(
          localStorage: SecureLocalStorage(),
        ),
      );
      _client = supabase.Supabase.instance.client;
      _initialized = true;
      _logger.info('Supabase initialized successfully.');
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to initialize Supabase: $error',
        error,
        stackTrace,
      );
      _initialized = false;
    }
    return _initialized;
  }
}
