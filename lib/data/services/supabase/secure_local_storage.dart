import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A [LocalStorage] that persists the Supabase auth session in the OS keychain
/// (flutter_secure_storage) instead of the default SharedPreferences.
///
/// The GoTrue client stores the full session — including the access and
/// refresh tokens — as one JSON blob. SharedPreferences is plaintext, so the
/// default storage would leave the auth tokens readable by anyone who can
/// extract app data. Secure storage keeps them behind the platform keystore
/// (Keychain/Keystore/DPAPI).
class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _sessionKey = 'nexfit.supabase.session';

  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      await _storage.containsKey(key: _sessionKey);

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<void> removePersistedSession() =>
      _storage.delete(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);
}