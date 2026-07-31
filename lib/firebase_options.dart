import 'package:firebase_core/firebase_core.dart';

/// Firebase options for the Android platform.
///
/// Values are injected at build time via `--dart-define` so that a project
/// can be configured without committing secrets:
///
/// ```
/// flutter run --dart-define=FIREBASE_API_KEY=... \
///             --dart-define=FIREBASE_APP_ID=... \
///             --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
///             --dart-define=FIREBASE_PROJECT_ID=...
/// ```
///
/// When no values are provided the app boots in offline-first mode and all
/// Firebase backed features degrade gracefully.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions? get currentPlatform {
    const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const String appId = String.fromEnvironment('FIREBASE_APP_ID');
    const String messagingSenderId =
        String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const String projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const String storageBucket =
        String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

    if (apiKey.isEmpty ||
        appId.isEmpty ||
        messagingSenderId.isEmpty ||
        projectId.isEmpty) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
    );
  }
}
