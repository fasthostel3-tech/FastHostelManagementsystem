import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final currentUserProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthService _authService;
  
  AuthNotifier(this._authService) : super(const AsyncValue.data(null)) {
    // Delay initialization to ensure Firebase is ready
    Future.microtask(() => _init());
  }
  
  void _init() {
    try {
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        try {
            // CRITICAL: Wait a brief moment to ensure auth state is fully propagated
            // This is especially important on Web where auth persistence causes delays
            await Future.delayed(const Duration(milliseconds: 100));
            
            // Fetch user document from Firestore using UID
            // getUser() will:
            // - Handle missing documents by creating one with UID and FCM token
            // - Handle documents with only FCM token gracefully
            // - Return UserModel with defaults for missing fields
            // - Never throw on errors, returns minimal UserModel instead
            debugPrint('[AuthProvider] Fetching user data for UID: ${user.uid}');
          final userModel = await _authService.getUser(user.uid);
            
            if (userModel != null) {
              // UserModel returned successfully (may have defaults for missing fields)
          state = AsyncValue.data(userModel);
              
              // Check if user data is minimal (only email or mostly empty)
              final isMinimalData = userModel.name.isEmpty && 
                                   userModel.phone.isEmpty &&
                                   userModel.arnRollNumber.isEmpty;
              
              if (isMinimalData) {
                debugPrint('[AuthProvider] User loaded with minimal data. Email: ${userModel.email}');
                debugPrint('[AuthProvider] App will continue with Firebase Auth. User can complete profile later.');
              } else {
                debugPrint('[AuthProvider] User loaded successfully. Email: ${userModel.email}, Name: ${userModel.name}');
              }
            } else {
              // getUser() returned null (shouldn't happen now, but handle it gracefully)
              debugPrint('[AuthProvider] Warning: getUser() returned null for UID: ${user.uid}');
              debugPrint('[AuthProvider] Using Firebase Auth only. Router will handle navigation.');
              // Set state to null - router will use Firebase Auth as fallback
              state = const AsyncValue.data(null);
            }
          } catch (e, stackTrace) {
            // Handle unexpected errors gracefully - allow navigation with Firebase Auth only
            debugPrint('[AuthProvider] Error loading user from Firestore: $e');
            debugPrint('[AuthProvider] Stack trace: $stackTrace');
            debugPrint('[AuthProvider] App will continue with Firebase Auth only.');
            // Set state to null instead of error - router will check Firebase Auth directly
            state = const AsyncValue.data(null);
        }
      } else {
          // User logged out - clear state
        state = const AsyncValue.data(null);
      }
    });
    } catch (e) {
      // If Firebase isn't ready yet, set error state
      debugPrint('Error initializing auth state listener: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
  
  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      debugPrint('Signing in user: $email');
      
      // Sign in with Firebase Authentication
      await _authService.signIn(email: email, password: password);
      
      // Wait for user data to be fetched from Firestore
      // The authStateChanges listener will automatically fetch user document by UID
      final authUser = _authService.currentUser;
      if (authUser != null) {
        debugPrint('Fetching user document from Firestore for UID: ${authUser.uid}');
        
        try {
          // Fetch user document from Firestore using UID
          // getUser() will:
          // - Handle missing documents by creating one with UID and FCM token
          // - Handle documents with only FCM token gracefully
          // - Return UserModel with defaults for missing fields
          // - Never throw on errors, returns minimal UserModel instead
          debugPrint('[AuthProvider] Sign-in: Fetching user data for UID: ${authUser.uid}');
          final userModel = await _authService.getUser(authUser.uid);
          
          if (userModel != null) {
            // UserModel returned successfully (may have defaults for missing fields)
            state = AsyncValue.data(userModel);
            
            // Check if user data is minimal (only email or mostly empty)
            final isMinimalData = userModel.name.isEmpty && 
                                 userModel.phone.isEmpty &&
                                 userModel.arnRollNumber.isEmpty;
            
            if (isMinimalData) {
              debugPrint('[AuthProvider] Login successful with minimal data. Email: ${userModel.email}');
              debugPrint('[AuthProvider] User profile can be completed later.');
            } else {
              debugPrint('[AuthProvider] Login successful. Email: ${userModel.email}, Name: ${userModel.name}');
            }
          } else {
            // getUser() returned null (shouldn't happen now, but handle it gracefully)
            debugPrint('[AuthProvider] Warning: getUser() returned null during sign-in for UID: ${authUser.uid}');
            debugPrint('[AuthProvider] Proceeding with Firebase Auth only. Router will handle navigation.');
            // Set state to data(null) - router will check Firebase Auth directly
            state = const AsyncValue.data(null);
          }
        } catch (e, stackTrace) {
          // Handle unexpected errors gracefully - allow login to proceed with Firebase Auth only
          debugPrint('[AuthProvider] Warning: Unexpected error during sign-in user fetch: $e');
          debugPrint('[AuthProvider] Stack trace: $stackTrace');
          debugPrint('[AuthProvider] Proceeding with Firebase Auth only.');
          // Set state to data(null) - router will check Firebase Auth directly
          state = const AsyncValue.data(null);
        }
      }
      // Note: authStateChanges listener will also update state automatically
    } catch (e) {
      debugPrint('Sign in error: $e');
      state = AsyncValue.error(e, StackTrace.current);
      rethrow; // Re-throw so login screen can handle the error
    }
  }
  
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String fathersName,
    required String arnRollNumber,
    required String phone,
    required Gender gender,
    required bool agreeToTerms,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authService.signUp(
        email: email,
        password: password,
        name: name,
        fathersName: fathersName,
        arnRollNumber: arnRollNumber,
        phone: phone,
        gender: gender,
        agreeToTerms: agreeToTerms,
      );
      // User will be updated via authStateChanges listener
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
  
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
  
  Future<void> createAdminAccount({
    required String email,
    required String password,
  }) async {
    try {
      await _authService.createAdminAccount(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow; // Let the UI show the actual error to the user
    }
  }
}

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.read(authServiceProvider);
  return authService.authStateChanges;
});