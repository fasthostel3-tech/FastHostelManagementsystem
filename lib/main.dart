import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:flutter/foundation.dart';

import 'config/router.dart';
import 'config/theme.dart';
import 'config/env_config.dart';
import 'config/app_keys.dart';
import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'services/local_notification_service.dart';
import 'services/app_check_service.dart';
import 'widgets/auth_gate.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize App Check in background handler
  try {
    await FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use
      androidProvider: AndroidProvider.debug,
      // ignore: deprecated_member_use
      appleProvider: AppleProvider.debug,
    );
  } catch (e) {
    // App Check initialization failure in background is non-critical
    debugPrint('App Check init warning in background handler: $e');
  }

  // Debug: Handling background message
  // ignore: avoid_print
  debugPrint("Handling a background message: ${message.messageId}");

  // Show local notification
  await LocalNotificationService.showNotification(
    id: message.hashCode,
    title: message.notification?.title ?? 'New Message',
    body: message.notification?.body ?? '',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize environment variables
    await EnvConfig.init();

    // Initialize Firebase - MUST succeed before app starts
    try {
      if (Firebase.apps.isEmpty) {
        final options = DefaultFirebaseOptions.currentPlatform;
        debugPrint('Initializing Firebase with project: ${options.projectId}');
        await Firebase.initializeApp(options: options)
            .timeout(const Duration(seconds: 10), onTimeout: () {
          debugPrint('Warning: Firebase.initializeApp timed out — proceeding anyway');
          return Firebase.app();
        });
        debugPrint('Firebase initialized successfully');
      } else {
        debugPrint('Firebase already initialized');
      }

      // Verify Firebase is ready
      final app = Firebase.app();
      debugPrint('Firebase app verified: ${app.name}');
      // On web, ensure auth persistence is set to LOCAL so users stay signed in across tabs
      if (kIsWeb) {
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
          debugPrint('Firebase Auth persistence set to LOCAL for web');
        } catch (e) {
          debugPrint('Warning: Failed to set web auth persistence: $e');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Firebase initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      // Re-throw to show error screen
      rethrow;
    }

    // Initialize Firebase App Check (optional - continue if it fails)
    // Uses Debug provider for development - no verification needed
    try {
      await AppCheckService.initialize();
      debugPrint('Firebase App Check initialized successfully');
    } catch (e) {
      debugPrint('Warning: Failed to initialize App Check: $e');
      // App Check is optional - app will continue without it
    }

    // Initialize local notifications (mobile only — not supported on web)
    if (!kIsWeb) {
      try {
        await LocalNotificationService.initialize();
      } catch (e) {
        debugPrint('Warning: Failed to initialize local notifications: $e');
      }
    }

    // Initialize FCM background handler only on mobile platforms.
    try {
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
      } else {
        debugPrint(
            'Skipping background message handler on Web (use service worker setup)');
      }
    } catch (e) {
      debugPrint('Warning: Failed to initialize FCM: $e');
    }

    runApp(const ProviderScope(child: SmartHostelApp()));
  } catch (e, stackTrace) {
    debugPrint('Initialization error: $e');
    debugPrint('Stack trace: $stackTrace');
    // If initialization fails, show error screen
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: AppKeys.scaffoldMessengerKey,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Initialization Error',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Error Details:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            e.toString(),
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 11),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Stack Trace:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            stackTrace.toString(),
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => main(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SmartHostelApp extends ConsumerWidget {
  const SmartHostelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // Set up foreground message handling
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Debug: Foreground message received
      // ignore: avoid_print
      debugPrint('Got a message whilst in the foreground!');
      // ignore: avoid_print
      debugPrint('Message data: ${message.data}');

      final notification = message.notification;
      if (notification != null) {
        LocalNotificationService.showNotification(
          id: message.hashCode,
          title: notification.title ?? 'New Message',
          body: notification.body ?? '',
        );
      }
    });

    // Wrap the app with AuthGate to ensure auth is ready before Firestore access
    return AuthGate(
      child: MaterialApp.router(
        scaffoldMessengerKey: AppKeys.scaffoldMessengerKey,
        title: 'Smart Hostel Management',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: ref.watch(routerProvider),
      ),
    );
  }
}
