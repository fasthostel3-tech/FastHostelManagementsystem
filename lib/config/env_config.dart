import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'web_config.dart';

class EnvConfig {
  // Cloudinary Configuration
  static String get cloudinaryCloudName {
    if (kIsWeb) return WebConfig.cloudinaryCloudName;
    return dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  }
  
  static String get cloudinaryApiKey {
    if (kIsWeb) return WebConfig.cloudinaryApiKey;
    return dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  }
  
  static String get cloudinaryApiSecret {
    if (kIsWeb) return ''; // NEVER expose secret on web
    return dotenv.env['CLOUDINARY_API_SECRET'] ?? '';
  }

  static String get cloudinaryUploadPreset {
    if (kIsWeb) return WebConfig.cloudinaryUploadPreset;
    return dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
  }

  // App Configuration
  static String get appName {
    if (kIsWeb) return 'Smart Hostel Management';
    return dotenv.env['APP_NAME'] ?? 'Smart Hostel Management';
  }
  
  static String get appVersion {
    if (kIsWeb) return '1.0.0';
    return dotenv.env['APP_VERSION'] ?? '1.0.0';
  }

  // Initialize environment variables
  static Future<void> init() async {
    // 1. Web: Do nothing. (Constants are in WebConfig)
    if (kIsWeb) {
      debugPrint('[EnvConfig] Web environment detected. Skipping .env load.');
      return;
    }

    // 2. Mobile: Load .env
    try {
      await dotenv.load(fileName: '.env');
      debugPrint('[EnvConfig] Environment variables loaded from .env');
    } catch (e) {
      // If .env is missing on mobile, we log a critical warning.
      // We do NOT try to fake it with testLoad.
      debugPrint('CRITICAL WARNING: Failed to load .env file: $e');
      debugPrint('Cloudinary and other env-dependent features WILL fail.');
    }
  }
}
