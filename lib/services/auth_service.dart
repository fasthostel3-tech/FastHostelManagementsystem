import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'notification_service.dart';
import 'admin_service.dart';

class AuthService {

  // Lazy initialization - only access Firebase when needed
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Validate university email or admin email
  bool isValidUniversityEmail(String email) {
    final lower = email.toLowerCase().trim();
    // Check if it's an admin email first
    if (AdminService.isApprovedAdminEmail(email)) {
      return true;
    }
    // Otherwise check if it's a valid university email
    return EmailValidator.validate(email) && lower.endsWith('@cfd.nu.edu.pk');
  }

  // Sign up with email and password (for students)
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
    required String fathersName,
    required String arnRollNumber,
    required String phone,
    required Gender gender,
    required bool agreeToTerms,
  }) async {
    try {
      // Validate email format and domain (allow admin emails too)
      if (!isValidUniversityEmail(email)) {
        throw Exception('Please use a valid university email (@cfd.nu.edu.pk)');
      }

      // Check if this is an admin email - admins should use AdminService to create accounts
      if (AdminService.isApprovedAdminEmail(email)) {
        throw Exception('Admin accounts must be created through the admin service');
      }

      // Validate terms agreement
      if (!agreeToTerms) {
        throw Exception('You must agree to the Hostel Rules and Regulations');
      }

      // Create user with email and password
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      if (user != null) {
        // Create user document in Firestore for the student profile
        final UserModel userModel = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          phone: phone,
          gender: gender,
          arnRollNumber: arnRollNumber,
          fathersName: fathersName,
          year: DateTime.now().year.toString(),
          status: 'active',
          role: UserRole.student, // Students default to student role
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestore
            .collection('profiles')
            .doc(user.uid)
            .set(userModel.toFirestore());

        return result;
      }
      return null;
    } catch (e) {
      throw Exception('Sign up failed: ${e.toString()}');
    }
  }

  /// Send email verification to current user (if any)
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      throw Exception('Failed to send verification email: ${e.toString()}');
    }
  }

  /// Reload current user and return whether email is verified
  Future<bool> isEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      await user.reload();
      return user.emailVerified;
    } catch (e) {
      throw Exception('Failed to check email verification: ${e.toString()}');
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Validate email is not null or empty
      if (email.isEmpty || email.trim().isEmpty) {
        throw Exception('Email cannot be empty');
      }

      // Validate email format (allows admin emails too)
      if (!isValidUniversityEmail(email)) {
        throw Exception('Please use a valid university email (@cfd.nu.edu.pk)');
      }

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Initialize notifications and persist token to profile for push from server
      try {
        final ns = NotificationService();
        await ns.initialize();
        final token = await ns.getToken();
        final user = result.user;
        if (token != null && user != null) {
          await ns.saveTokenForUser(user.uid, token);
        }
      } catch (e) {
        // Non-fatal: notification persistence shouldn't block sign-in
        // ignore: avoid_print
        debugPrint('Warning: failed to initialize notifications on sign-in: $e');
      }
      return result;
    } on FirebaseAuthException catch (e) {
      // Preserve Firebase Auth error codes for proper error handling
      debugPrint('Firebase Auth error: ${e.code} - ${e.message}');
      throw Exception('Sign in failed: ${e.code}');
    } catch (e) {
      debugPrint('Sign in error: $e');
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  // Reset password (supports admin emails too)
  Future<void> resetPassword(String email) async {
    try {
      if (!isValidUniversityEmail(email)) {
        throw Exception('Please use a valid university email (@cfd.nu.edu.pk)');
      }
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] resetPassword error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No account found for this email. The account may not have been created yet.');
        case 'invalid-email':
          throw Exception('Invalid email address format.');
        case 'too-many-requests':
          throw Exception('Too many requests. Please wait a few minutes and try again.');
        default:
          throw Exception('Password reset failed: ${e.message ?? e.code}');
      }
    } catch (e) {
      throw Exception('Password reset failed: ${e.toString()}');
    }
  }

  // Create admin account directly (used when admin account doesn't exist in Firebase Auth)
  Future<void> createAdminAccount({
    required String email,
    required String password,
  }) async {
    try {
      if (!AdminService.isApprovedAdminEmail(email)) {
        throw Exception('Email is not in the approved admin list.');
      }
      // Create the Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) throw Exception('Account creation failed.');
      // Create Firestore profile with admin role
      await FirebaseFirestore.instance.collection('profiles').doc(user.uid).set({
        'name': 'Admin',
        'email': email.trim(),
        'role': 'admin',
        'status': 'active',
        'phone': '',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
      debugPrint('[AuthService] Admin account created: $email');
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('An account already exists for this email. Use Forgot Password to reset it.');
        case 'weak-password':
          throw Exception('Password is too weak. Use at least 6 characters.');
        default:
          throw Exception('Account creation failed: ${e.message ?? e.code}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Gets user data from Firestore by UID.
  /// 
  /// This method:
  /// - Fetches the user document from 'profiles' collection
  /// - Handles documents that only contain FCM token gracefully
  /// - Creates a new document with UID and FCM token if document doesn't exist
  /// - Returns UserModel with defaults for missing fields
  /// - Logs meaningful messages for debugging
  /// - Returns null on critical errors (allows app to continue with Firebase Auth only)
  /// 
  /// Returns:
  /// - UserModel if document exists or was created successfully
  /// - null if critical error occurs (network, permissions, etc.)
  /// 
  /// Errors:
  /// - Network errors: Returns null, logs warning
  /// - Permission errors: Returns null, logs warning
  /// - Missing fields: Uses defaults, logs info about missing fields
  Future<UserModel?> getUser(String uid) async {
    try {
      // Validate UID
      if (uid.isEmpty) {
        debugPrint('Error: UID cannot be empty');
        return null;
      }

      debugPrint('[Firestore] Fetching user document: profiles/$uid');
      
      // Attempt to fetch document from Firestore
      final DocumentSnapshot doc = await _firestore
          .collection('profiles')
          .doc(uid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('[Firestore] Timeout: Request took longer than 10 seconds');
              throw Exception('Network timeout');
            },
          );

      if (doc.exists) {
        // Document exists - parse it
        final data = doc.data() as Map<String, dynamic>? ?? {};

        // Log available fields for debugging
        final availableFields = data.keys.toList();
        debugPrint('[Firestore] Document exists. Available fields: $availableFields');

        // Check if document only has FCM token (or minimal data)
        final hasOnlyFcmToken = data.length <= 2 &&
            (data.containsKey('fcmTokens') || data.containsKey('fcmToken'));

        if (hasOnlyFcmToken) {
          debugPrint('[Firestore] Document contains only FCM token data. Proceeding with defaults.');
        }

        // Get email from Firebase Auth user if not in Firestore data
        final authUser = _auth.currentUser;
        final email = data['email'] ?? authUser?.email ?? '';

        // Auto-fix: If this is an approved admin email but the stored role is not
        // 'admin', correct it immediately so the admin can always log in.
        if (AdminService.isApprovedAdminEmail(email)) {
          final storedRole = (data['role'] ?? '').toString();
          if (storedRole != 'admin') {
            debugPrint('[Firestore] Admin email detected with wrong role "$storedRole". Auto-correcting to admin.');
            data['role'] = 'admin';
            try {
              await _firestore.collection('profiles').doc(uid).set(
                {'role': 'admin', 'email': email, 'status': 'active', 'updatedAt': DateTime.now()},
                SetOptions(merge: true),
              );
            } catch (e) {
              debugPrint('[Firestore] Warning: could not persist admin role fix: $e');
            }
          }
        }
        
        // Check for missing critical fields and log them
        final missingFields = <String>[];
        if ((data['name'] ?? '').toString().isEmpty) missingFields.add('name');
        if (email.isEmpty) missingFields.add('email');
        if ((data['createdAt']) == null) missingFields.add('createdAt');
        if ((data['updatedAt']) == null) missingFields.add('updatedAt');
        
        if (missingFields.isNotEmpty) {
          debugPrint('[Firestore] Missing fields handled with defaults: $missingFields');
        }
        
        // Add email from Firebase Auth if missing from Firestore
        if (email.isNotEmpty && !data.containsKey('email')) {
          data['email'] = email;
          debugPrint('[Firestore] Using email from Firebase Auth: $email');
        }
        
        try {
          // Create UserModel with graceful field handling
          final userModel = UserModel.fromMap(data, uid: uid);
          
          // If email is still empty, try to get from Firebase Auth
          if (userModel.email.isEmpty && authUser?.email != null) {
            final updatedModel = userModel.copyWith(email: authUser?.email ?? '');
            debugPrint('[Firestore] User data loaded successfully. Email: ${updatedModel.email}');
            return updatedModel;
          }
          
          debugPrint('[Firestore] User data loaded successfully. Email: ${userModel.email}');
          return userModel;
        } catch (parseError) {
          // If parsing fails, log error but try to continue with minimal data
          debugPrint('[Firestore] Warning: Error parsing user data: $parseError');
          debugPrint('[Firestore] Attempting to create UserModel with defaults...');
          
          // Create minimal UserModel with defaults
          return UserModel(
            uid: uid,
            name: data['name']?.toString() ?? '',
            email: email,
            phone: data['phone']?.toString() ?? '',
            gender: Gender.male,
            arnRollNumber: data['arnRollNumber']?.toString() ?? '',
            fathersName: data['fathersName']?.toString() ?? '',
            year: data['year']?.toString() ?? '',
            status: data['status']?.toString() ?? 'active',
            role: UserRole.student, // Default to student
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      } else {
        // Document doesn't exist - create it with UID and FCM token
        debugPrint('[Firestore] Document not found: profiles/$uid');
        debugPrint('[Firestore] Creating new document with UID and FCM token...');
        
        try {
          // Get FCM token if available
          String? fcmToken;
          try {
            final ns = NotificationService();
            await ns.initialize();
            fcmToken = await ns.getToken();
    } catch (e) {
            debugPrint('[Firestore] Warning: Could not get FCM token: $e');
          }
          
          // Get email from Firebase Auth
          final authUser = _auth.currentUser;
          final email = authUser?.email ?? '';
          
          // Determine role — admin emails must always get the admin role
          final newRole = AdminService.isApprovedAdminEmail(email) ? 'admin' : 'student';
          debugPrint('[Firestore] Creating new profile with role: $newRole for $email');

          // Create minimal document with UID, email, and FCM token
          final newData = <String, dynamic>{
            'email': email,
            'role': newRole,
            'status': 'active',
            'createdAt': DateTime.now(),
            'updatedAt': DateTime.now(),
          };
          
          // Add FCM token if available
          if (fcmToken != null) {
            newData['fcmTokens'] = FieldValue.arrayUnion([fcmToken]);
            debugPrint('[Firestore] Document created with FCM token');
          } else {
            debugPrint('[Firestore] Document created without FCM token');
          }
          
          // Write document to Firestore
          await _firestore
              .collection('profiles')
        .doc(uid)
              .set(newData, SetOptions(merge: false));
          
          debugPrint('[Firestore] Document created successfully: profiles/$uid');
          
          // Return UserModel with minimal data
          final resolvedRole = AdminService.isApprovedAdminEmail(email) ? UserRole.admin : UserRole.student;
          return UserModel(
            uid: uid,
            name: '',
            email: email,
            phone: '',
            gender: Gender.male,
            arnRollNumber: '',
            fathersName: '',
            year: '',
            status: 'active',
            role: resolvedRole,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        } catch (createError) {
          // If document creation fails, log error but don't crash
          debugPrint('[Firestore] Warning: Failed to create document: $createError');
          debugPrint('[Firestore] App will continue with Firebase Auth only');

          final authUser = _auth.currentUser;
          final fallbackEmail = authUser?.email ?? '';
          final fallbackRole = AdminService.isApprovedAdminEmail(fallbackEmail) ? UserRole.admin : UserRole.student;
          return UserModel(
            uid: uid,
            name: '',
            email: fallbackEmail,
            phone: '',
            gender: Gender.male,
            arnRollNumber: '',
            fathersName: '',
            year: '',
            status: 'active',
            role: fallbackRole,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      }
    } on FirebaseException catch (e) {
      // Handle Firebase-specific errors
      debugPrint('[Firestore] Firebase error: ${e.code} - ${e.message}');

      if (e.code == 'permission-denied') {
        debugPrint('[Firestore] Permission denied. App will continue with Firebase Auth only.');
      } else if (e.code == 'unavailable') {
        debugPrint('[Firestore] Service unavailable. App will continue with Firebase Auth only.');
      } else if (e.code == 'unauthenticated') {
        debugPrint('[Firestore] Unauthenticated. App will continue with Firebase Auth only.');
      }

      final authUser = _auth.currentUser;
      final fallbackEmail = authUser?.email ?? '';
      final fallbackRole = AdminService.isApprovedAdminEmail(fallbackEmail) ? UserRole.admin : UserRole.student;
      return UserModel(
        uid: uid,
        name: '',
        email: fallbackEmail,
        phone: '',
        gender: Gender.male,
        arnRollNumber: '',
        fathersName: '',
        year: '',
        status: 'active',
        role: fallbackRole,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e, stackTrace) {
      // Handle all other errors (network, timeout, etc.)
      debugPrint('[Firestore] Error fetching user data for UID $uid: $e');
      debugPrint('[Firestore] Stack trace: $stackTrace');
      debugPrint('[Firestore] App will continue with Firebase Auth only');
      
      // Return minimal UserModel using Firebase Auth data instead of throwing
      // This allows the app to continue functioning
      final authUser = _auth.currentUser;
      final catchEmail = authUser?.email ?? '';
      final catchRole = AdminService.isApprovedAdminEmail(catchEmail) ? UserRole.admin : UserRole.student;
      return UserModel(
        uid: uid,
        name: '',
        email: catchEmail,
        phone: '',
        gender: Gender.male,
        arnRollNumber: '',
        fathersName: '',
        year: '',
        status: 'active',
        role: catchRole,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  // Update user data
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = DateTime.now();
      await _firestore
          .collection('profiles')
          .doc(uid)
          .update(data);
    } catch (e) {
      throw Exception('Failed to update user: ${e.toString()}');
    }
  }

  // Delete user account
  Future<void> deleteUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Delete user data from Firestore
        await _firestore.collection('profiles').doc(user.uid).delete();
        
        // Delete user account
        await user.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }
}















