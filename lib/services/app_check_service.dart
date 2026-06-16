import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Service to initialize and manage Firebase App Check
///
/// For development: Uses Debug provider (no verification needed)
/// For production: Replace with DeviceCheckProvider (iOS) or PlayIntegrityProvider (Android)
class AppCheckService {
  /// Set to false to disable App Check entirely (for development)
  /// Set to true to enable App Check (requires debug token registration for debug builds)
  static const bool enableAppCheck = true;

  /// Initialize Firebase App Check
  ///
  /// Uses Debug provider for development builds.
  /// In production, you should use:
  /// - Android: PlayIntegrityProvider
  /// - iOS: DeviceCheckProvider
  /// - Web: ReCaptchaEnterpriseProvider
  ///
  /// NOTE: For Debug provider to work, you need to register the debug token in Firebase Console:
  /// 1. Run the app and check logs for: "Enter this debug secret into the allow list..."
  /// 2. Go to Firebase Console → Build → App Check → Your Android app
  /// 3. Click "Debug tokens" tab → "Add debug token"
  /// 4. Paste the token from logs and save
  static Future<void> initialize() async {
    // Skip App Check if disabled
    if (!enableAppCheck) {
      debugPrint('App Check is disabled (enableAppCheck = false)');
      return;
    }

    try {
      // Initialize App Check with Debug provider for development on mobile platforms
      // Web has a separate provider (ReCaptcha) and requires site key configuration.
      if (kIsWeb) {
        debugPrint(
            'Skipping App Check activation on web. Configure web provider if needed.');
      } else {
        // This allows testing without production verification on mobile
        await FirebaseAppCheck.instance.activate(
          // ignore: deprecated_member_use
          androidProvider: AndroidProvider.debug,
          // ignore: deprecated_member_use
          appleProvider: AppleProvider.debug,
        );

        debugPrint('Firebase App Check initialized with Debug provider');
        debugPrint(
            'If you see App Check errors, register the debug token in Firebase Console');
      }
    } catch (e) {
      // Log error but don't block app startup
      // App Check is optional for basic functionality
      debugPrint('Warning: Failed to initialize App Check: $e');
      debugPrint(
          'App Check is optional and the app will continue to work without it');
      debugPrint(
          'To fix: Register debug token in Firebase Console or set enableAppCheck = false');
    }
  }

  /// Get the current App Check token (for debugging)
  static Future<String?> getToken() async {
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      return token;
    } catch (e) {
      debugPrint('Failed to get App Check token: $e');
      return null;
    }
  }
}
