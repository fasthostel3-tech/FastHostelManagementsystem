import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'gym_service.dart';
import 'mess_registration_service.dart';

/// Service for managing admin accounts and operations
class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// List of approved admin emails
  static const List<String> approvedAdminEmails = [
    'fasthostel3@gmail.com',
  ];

  /// Check if an email is an approved admin email
  static bool isApprovedAdminEmail(String email) {
    return approvedAdminEmails.contains(email.toLowerCase().trim());
  }

  /// Check if current user is admin based on their profile role
  Future<bool> isCurrentUserAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore.collection('profiles').doc(user.uid).get();
      if (!doc.exists) return false;

      final role = doc.data()?['role'] as String?;
      return role == 'admin';
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  /// Check if a user is admin by their UserModel
  static bool isAdmin(UserModel? user) {
    if (user == null) return false;
    return user.role == UserRole.admin;
  }

  /// Create an admin account
  /// This should be called from Firebase Console or a secure admin panel
  Future<void> createAdminAccount({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      // Validate admin email
      if (!isApprovedAdminEmail(email)) {
        throw Exception('Email is not in the approved admin list');
      }

      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Failed to create Firebase Auth user');
      }

      // Create admin profile in Firestore
      await _firestore.collection('profiles').doc(user.uid).set({
        'name': name,
        'email': email,
        'phone': phone ?? '',
        'role': 'admin',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Admin account created successfully: $email');
    } catch (e) {
      debugPrint('Error creating admin account: $e');
      rethrow;
    }
  }

  /// Update user role (admin only operation)
  Future<void> updateUserRole(String userId, UserRole role) async {
    try {
      // Verify current user is admin
      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) {
        throw Exception('Only admins can update user roles');
      }

      await _firestore.collection('profiles').doc(userId).update({
        'role': role.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('User role updated: $userId -> $role');
    } catch (e) {
      debugPrint('Error updating user role: $e');
      rethrow;
    }
  }

  /// Update existing user to admin role (for setup purposes)
  /// This bypasses admin check - use only for initial setup
  Future<void> setUserAsAdmin(String userId, {String? name, String? email}) async {
    try {
      final updateData = <String, dynamic>{
        'role': 'admin',
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (email != null) updateData['email'] = email;

      // Set createdAt if document doesn't exist
      final doc = await _firestore.collection('profiles').doc(userId).get();
      if (!doc.exists || doc.data()?['createdAt'] == null) {
        updateData['createdAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection('profiles').doc(userId).set(
        updateData,
        SetOptions(merge: true),
      );

      debugPrint('User set as admin: $userId');
    } catch (e) {
      debugPrint('Error setting user as admin: $e');
      rethrow;
    }
  }

  /// Clear all registrations (gym and mess) - sets all active registrations to rejected
  Future<void> clearAllRegistrations() async {
    try {
      // Verify current user is admin
      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) {
        throw Exception('Only admins can clear registrations');
      }

      final gymService = GymService();
      final messRegistrationService = MessRegistrationService();

      // Clear gym registrations
      await gymService.clearAllRegistrations();
      
      // Clear mess registrations
      await messRegistrationService.clearAllRegistrations();

      debugPrint('All registrations cleared successfully');
    } catch (e) {
      debugPrint('Error clearing registrations: $e');
      rethrow;
    }
  }
}

