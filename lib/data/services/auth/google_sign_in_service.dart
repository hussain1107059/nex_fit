import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/app_exception.dart';

/// Wraps the native Google Sign-In flow (google_sign_in 7.x).
///
/// The server client id can be injected at build time:
/// `--dart-define=GOOGLE_SIGN_IN_SERVER_CLIENT_ID=...`
class GoogleSignInService {
  GoogleSignInService();

  static const String _serverClientId = String.fromEnvironment(
    'GOOGLE_SIGN_IN_SERVER_CLIENT_ID',
  );

  static const List<String> _driveScopes = <String>[
    'https://www.googleapis.com/auth/drive.file',
    // Grants access to the private AppData folder used for backups.
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  static bool _initialized = false;

  GoogleSignInAccount? _currentUser;

  bool get isInitialized => _initialized;

  /// Initializes the Google Sign-In singleton. Must be awaited exactly once
  /// before any other method is used.
  Future<void> initialize() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
    );
    _initialized = true;
  }

  GoogleSignInAccount? get currentUser => _currentUser;

  /// Starts an interactive Google Sign-In flow.
  Future<GoogleSignInAccount> authenticate() async {
    try {
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate(scopeHint: _driveScopes);
      _currentUser = account;
      return account;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthException('authCancelled', code: 'cancelled');
      }
      throw const AuthException(
        'authGoogleSignInFailed',
        code: 'google_sign_in_failed',
      );
    }
  }

  /// Attempts to restore a previously signed-in user with minimal UI.
  Future<GoogleSignInAccount?> attemptSilentSignIn() async {
    final Future<GoogleSignInAccount?>? future = GoogleSignIn.instance
        .attemptLightweightAuthentication();
    if (future == null) return null;
    try {
      final GoogleSignInAccount? account = await future;
      _currentUser = account;
      return account;
    } on GoogleSignInException {
      _currentUser = null;
      return null;
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    _currentUser = null;
  }

  Future<void> disconnect() async {
    await GoogleSignIn.instance.disconnect();
    _currentUser = null;
  }

  /// Returns an [http.Client] pre-authenticated for the current user so the
  /// Google Drive backup service can call the Drive API.
  /// Returns null when the user is not signed in.
  Future<http.Client?> driveAuthorizedClient() async {
    final GoogleSignInAccount? account = _currentUser;
    if (account == null) return null;

    final GoogleSignInAuthorizationClient authorizationClient =
        account.authorizationClient;
    try {
      final Map<String, String>? headers = await authorizationClient
          .authorizationHeaders(_driveScopes, promptIfNecessary: true);
      if (headers == null) return null;
      return _AuthorizedClient(http.Client(), headers);
    } on GoogleSignInException {
      return null;
    }
  }
}

/// Thin [http.BaseClient] that injects pre-computed authorization headers
/// (e.g. `Authorization: Bearer ...`) into every request.
class _AuthorizedClient extends http.BaseClient {
  _AuthorizedClient(this._inner, this._headers);

  final http.Client _inner;
  final Map<String, String> _headers;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
