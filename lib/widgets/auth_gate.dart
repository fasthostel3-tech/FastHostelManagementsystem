import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Provider that tracks when Firebase Auth is fully initialized and ready
/// This is critical for Web where auth persistence can cause delays
final authReadyProvider = StreamProvider<bool>((ref) async* {
  final auth = FirebaseAuth.instance;
  
  // First, check if currentUser is already available (fast path)
  if (auth.currentUser != null) {
    yield true;
  }
  
  // Then wait for the first auth state change event which indicates auth is ready
  // This handles the case where auth state is being restored (especially on Web)
  await for (final _ in auth.authStateChanges()) {
    // First emission means auth state is initialized
    yield true;
    // After first emission, we know auth is ready
    // We can break here since we only need to know when auth is initially ready
    break;
  }
});

/// AuthGate widget that ensures Firebase Auth is fully initialized
/// before allowing the app to access Firestore
/// 
/// This prevents permission-denied errors that occur when Firestore
/// is accessed before auth state is ready, especially on Web.
class AuthGate extends ConsumerWidget {
  final Widget child;
  final Widget? loadingWidget;

  const AuthGate({
    super.key,
    required this.child,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authReady = ref.watch(authReadyProvider);

    return authReady.when(
      data: (isReady) {
        if (!isReady) {
          return loadingWidget ??
              const Directionality(
                textDirection: TextDirection.ltr,
                child: Material(
                  child: Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              );
        }

        // Auth is ready - render the app
        // The router will handle navigation based on auth state
        return child;
      },
      loading: () => loadingWidget ??
          const Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              child: Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ),
      error: (error, stackTrace) {
        debugPrint('AuthGate error: $error');
        // Even if auth readiness check fails, allow app to continue
        // The router will handle auth state checking
        return child;
      },
    );
  }
}

/// Helper function to check if auth is ready before accessing Firestore
/// Use this in services before making Firestore calls
Future<bool> ensureAuthReady() async {
  final auth = FirebaseAuth.instance;
  
  if (kIsWeb) {
    // On Web, wait for auth state to be restored
    // Check if currentUser is available, if not wait for authStateChanges
    if (auth.currentUser != null) {
      return true;
    }
    
    // Wait for first auth state change (with timeout)
    try {
      await auth.authStateChanges().first.timeout(
        const Duration(seconds: 5),
      );
      return true;
    } catch (e) {
      debugPrint('Auth readiness check timeout: $e');
      // Return true if currentUser is available, false otherwise
      return auth.currentUser != null;
    }
  } else {
    // On mobile, auth is typically ready immediately
    // But we still check currentUser to be safe
    if (auth.currentUser != null) {
      return true;
    }
    
    try {
      await auth.authStateChanges().first.timeout(
        const Duration(seconds: 2),
      );
      return true;
    } catch (e) {
      debugPrint('Auth readiness check timeout on mobile: $e');
      return auth.currentUser != null;
    }
  }
}

/// Helper function to get current user with auth readiness check
/// Returns null if auth is not ready or user is not authenticated
/// This should be called before any Firestore operations
/// 
/// On Web, this also ensures the auth token is refreshed and propagated
/// to Firestore before returning, preventing permission-denied errors.
Future<User?> getCurrentUserWithAuthCheck() async {
  try {
    final isReady = await ensureAuthReady();
    if (!isReady) {
      debugPrint('[AuthGate] Auth not ready - cannot access Firestore');
      return null;
    }
    
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    
    if (user == null) {
      debugPrint('[AuthGate] No authenticated user - cannot access Firestore');
      return null;
    }
    
    // CRITICAL: On Web, refresh the auth token to ensure it's propagated to Firestore
    // This prevents permission-denied errors where auth is verified but token isn't attached
    if (kIsWeb) {
      try {
        // Reload user to refresh token
        await user.reload();
        // Small delay to ensure token propagation to Firestore
        await Future.delayed(const Duration(milliseconds: 200));
        debugPrint('[AuthGate] Auth token refreshed for Firestore. User: ${user.uid}');
      } catch (e) {
        debugPrint('[AuthGate] Warning: Could not refresh auth token: $e');
        // Continue anyway - token might still be valid
      }
    }
    
    debugPrint('[AuthGate] Auth verified. User: ${user.uid}');
    return user;
  } catch (e) {
    debugPrint('[AuthGate] Error checking auth: $e');
    return null;
  }
}
