import 'package:firebase_core/firebase_core.dart';
import 'package:logging/logging.dart';

import '../../firebase_options.dart';

/// Owns the Firebase lifecycle for the app.
///
/// Firebase is optional: when build-time configuration is missing the app
/// still runs fully offline. Every Firebase-backed feature must call
/// [isReady] before use.
class FirebaseService {
  FirebaseService({Logger? logger}) : _logger = logger ?? Logger('FirebaseService');

  final Logger _logger;

  bool _initialized = false;

  bool get isReady => _initialized;

  Future<bool> initialize() async {
    if (_initialized) return true;

    final FirebaseOptions? options = DefaultFirebaseOptions.currentPlatform;
    if (options == null) {
      _logger.info('Firebase configuration not provided. Running offline.');
      return false;
    }

    try {
      await Firebase.initializeApp(options: options);
      _initialized = true;
      _logger.info('Firebase initialized successfully.');
    } catch (error, stackTrace) {
      _logger.warning('Failed to initialize Firebase: $error', error, stackTrace);
      _initialized = false;
    }
    return _initialized;
  }
}
