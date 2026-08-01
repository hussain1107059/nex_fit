import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Wraps biometric authentication (fingerprint / face) and the platform-side
/// "hide recent apps preview" flag. Every call is guarded so an unsupported
/// platform or a missing channel can never crash the app.
class AppSecurityService {
  AppSecurityService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  static const MethodChannel _channel = MethodChannel('nexfit/security');

  final LocalAuthentication _localAuth;

  /// Whether the device exposes a usable biometric sensor.
  Future<bool> isBiometricSupported() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return false;
    }
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool hasEnrolled = await _localAuth.isDeviceSupported();
      return canCheck && hasEnrolled;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user with the system biometric dialog.
  Future<bool> authenticate({required String reason}) async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return false;
    }
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Turns the Android FLAG_SECURE window flag on/off so the app's content is
  /// hidden from the recents preview. No-op on other platforms.
  Future<void> applyHideRecentApps(bool enabled) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', <String, Object?>{
        'enabled': enabled,
      });
    } catch (_) {
      // The channel is missing on some Android flavours; ignore gracefully.
    }
  }
}
