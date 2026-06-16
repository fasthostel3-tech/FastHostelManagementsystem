import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_gate.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/admin_login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/awaiting_verification_screen.dart';
import '../screens/student/student_dashboard.dart';
import '../screens/student/hostel_allotment/hostel_application_screen.dart';
import '../screens/student/hostel_allotment/room_selection_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/mess_screen.dart';
import '../screens/student/complaint_box_screen.dart';
import '../screens/student/gym_registration_screen.dart';
import '../screens/student/mess_attendance_screen.dart';
import '../screens/student/room_swap_screen.dart';
import '../screens/student/hostel_browse_screen.dart';
import '../screens/payments_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/applications_management_screen.dart';
import '../screens/admin/complaints_management_screen.dart';
import '../screens/admin/fee_payments_screen.dart';
import '../screens/admin/bank_settings_screen.dart';
import '../screens/admin/gym_management_screen.dart';
import '../screens/admin/hall_management_screen.dart';
import '../screens/admin/hostel_management_screen.dart';
import '../screens/admin/mess_attendance_management_screen.dart';
import '../screens/admin/mess_management_screen.dart';
import '../screens/admin/mess_billing_screen.dart'; // Import Mess Billing Screen
import '../screens/admin/room_requests_screen.dart';
import '../screens/admin/hall_detail_screen.dart';
import '../screens/admin/notice_board_management_screen.dart';
import '../screens/admin/clear_data_screen.dart';
import '../screens/admin/admin_analytics_screen.dart';
import '../screens/notice_board_screen.dart';
import '../screens/landing_page.dart';
import '../utils/admin_utils.dart';

CustomTransitionPage<T> fadeSlidePage<T>(LocalKey key, Widget child) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 240),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  final authReady = ref.watch(authReadyProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final location = state.uri.toString();
      final isAwaitingVerification =
          location.startsWith('/auth/awaiting-verification');

      // Allow awaiting verification screen regardless of auth state
      if (isAwaitingVerification) {
        return null;
      }

      // Wait for auth to be ready before making routing decisions
      // This is critical on Web where auth persistence causes delays
      final isAuthReady = authReady.when(
        data: (ready) => ready,
        loading: () => false, // Wait for auth to be ready
        error: (_, __) => true, // On error, proceed (router will handle it)
      );

      // If auth is not ready yet, don't redirect (stay on current route)
      // The AuthGate will show loading until auth is ready
      if (!isAuthReady) {
        return null;
      }

      // Check Firebase Auth directly as fallback if provider is in error state
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final hasFirebaseAuth = firebaseUser != null;

      // Check provider state for Firestore user data
      final userModel = currentUser.when(
        data: (user) => user,
        loading: () => null,
        error: (_, __) => null, // Don't block navigation on Firestore errors
      );

      final hasProviderUser = userModel != null;
      final isLoggedIn = hasFirebaseAuth || hasProviderUser;
      final isAdmin = AdminUtils.isAdmin(userModel);

      // Landing page is public — everyone may view it, signed in or not.
      // Signed-in users continue to their dashboard via the navbar button.
      if (location == '/') {
        return null;
      }

      // If not logged in and trying to access protected routes
      if (!isLoggedIn && !location.startsWith('/auth')) {
        return '/auth/login';
      }

      // Admin-login route is intentionally open to logged-in students so they
      // can switch to an admin account without being bounced to their dashboard.
      // Only admins that are already authenticated skip past it.
      if (location == '/auth/admin-login') {
        if (isAdmin) return '/admin/dashboard';
        return null; // students and guests may proceed to admin login
      }

      // Role-based redirection when logged in (all other /auth/* routes)
      if (isLoggedIn &&
          location.startsWith('/auth') &&
          !isAwaitingVerification) {
        // Redirect to appropriate dashboard based on role
        if (isAdmin) {
          return '/admin/dashboard';
        } else {
          return '/student/dashboard';
        }
      }

      // Role-based redirection on splash screen
      if (isLoggedIn && location == '/splash') {
        if (isAdmin) {
          return '/admin/dashboard';
        } else {
          return '/student/dashboard';
        }
      }

      // Protect admin routes - only admins can access
      if (isLoggedIn && location.startsWith('/admin') && !isAdmin) {
        return '/student/dashboard'; // Redirect non-admins to student dashboard
      }

      // Protect student routes - redirect admins to admin dashboard
      if (isLoggedIn && location.startsWith('/student') && isAdmin) {
        return '/admin/dashboard'; // Redirect admins to admin dashboard
      }

      // If not logged in and on splash screen, redirect to login
      if (!isLoggedIn && location == '/splash') {
        return '/auth/login';
      }

      return null;
    },
    routes: [
      // Public landing page
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => fadeSlidePage<void>(
          state.pageKey,
          const LandingPage(),
        ),
      ),
      // Friendly alias used in some deployments
      GoRoute(
        path: '/fast',
        redirect: (context, state) => '/splash',
      ),
      // Splash Screen
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => fadeSlidePage<void>(
          state.pageKey,
          const SplashScreen(),
        ),
      ),

      // Authentication Routes
      GoRoute(
        path: '/auth/login',
        pageBuilder: (context, state) => fadeSlidePage<void>(
          state.pageKey,
          const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/admin-login',
        pageBuilder: (context, state) => fadeSlidePage<void>(
          state.pageKey,
          const AdminLoginScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/signup',
        pageBuilder: (context, state) => fadeSlidePage<void>(
          state.pageKey,
          const SignupScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        pageBuilder: (context, state) => fadeSlidePage<void>(
          state.pageKey,
          const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/auth/awaiting-verification',
        pageBuilder: (context, state) => fadeSlidePage<void>(
          state.pageKey,
          const AwaitingVerificationScreen(),
        ),
      ),

      // Student Routes
      GoRoute(
        path: '/student/dashboard',
        pageBuilder: (context, state) => fadeSlidePage<void>(
          state.pageKey,
          const StudentDashboard(),
        ),
        routes: [
          GoRoute(
            path: 'hostel-application',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const HostelApplicationScreen(),
            ),
          ),
          GoRoute(
            path: 'room-selection',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const RoomSelectionScreen(),
            ),
          ),
          GoRoute(
            path: 'profile',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const ProfileScreen(),
            ),
          ),
          GoRoute(
            path: 'notifications',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: 'notice-board',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const NoticeBoardScreen(),
            ),
          ),
          GoRoute(
            path: 'mess',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const MessScreen(),
            ),
          ),
          GoRoute(
            path: 'mess-attendance',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const MessAttendanceScreen(),
            ),
          ),
          GoRoute(
            path: 'gym-registration',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const GymRegistrationScreen(),
            ),
          ),
          GoRoute(
            path: 'complaint-box',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const ComplaintBoxScreen(),
            ),
          ),
          GoRoute(
            path: 'room-swap',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const RoomSwapScreen(),
            ),
          ),
          GoRoute(
            path: 'payments',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const PaymentsScreen(),
            ),
          ),
          GoRoute(
            path: 'browse-hostels',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const HostelBrowseScreen(),
            ),
          ),
        ],
      ),

      // Admin Routes
      GoRoute(
        path: '/admin/dashboard',
        pageBuilder: (context, state) => fadeSlidePage<void>(
          state.pageKey,
          const AdminDashboard(),
        ),
        routes: [
          GoRoute(
            path: 'hostel-management',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const HostelManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'applications',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const ApplicationsManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'room-requests',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const RoomRequestsScreen(),
            ),
          ),
          GoRoute(
            path: 'fee-payments',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const FeePaymentsScreen(),
            ),
          ),
          GoRoute(
            path: 'bank-settings',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const BankSettingsScreen(),
            ),
          ),
          GoRoute(
            path: 'halls',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const HallManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'halls/:hallId',
            pageBuilder: (context, state) {
              final hallId = state.pathParameters['hallId']!;
              return fadeSlidePage<void>(
                state.pageKey,
                HallDetailScreen(hallId: hallId),
              );
            },
          ),
          GoRoute(
            path: 'mess-management',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const MessManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'mess-attendance',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const MessAttendanceManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'mess-billing',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const MessBillingScreen(),
            ),
          ),
          GoRoute(
            path: 'gym-management',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const GymManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'complaints',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const ComplaintsManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'notice-board',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const NoticeBoardManagementScreen(),
            ),
          ),
          GoRoute(
            path: 'db-management',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const ClearDataScreen(),
            ),
          ),
          GoRoute(
            path: 'analytics',
            pageBuilder: (context, state) => fadeSlidePage<void>(
              state.pageKey,
              const AdminAnalyticsScreen(),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri.toString()}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/splash'),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

class AppRouter {
  static final router = routerProvider;
}
