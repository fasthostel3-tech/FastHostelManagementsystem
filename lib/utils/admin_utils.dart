import '../models/user_model.dart';
import '../services/admin_service.dart';

/// Utility functions for admin-related operations
class AdminUtils {
  /// Check if a user is an admin
  static bool isAdmin(UserModel? user) {
    if (user == null) return false;
    return user.role == UserRole.admin;
  }

  /// Check if an email is an approved admin email
  static bool isApprovedAdminEmail(String email) {
    return AdminService.isApprovedAdminEmail(email);
  }

  /// Get user role as string for display
  static String getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.student:
        return 'Student';
    }
  }
}

