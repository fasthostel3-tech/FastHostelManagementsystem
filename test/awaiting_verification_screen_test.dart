import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:fast_hostel_system/screens/auth/awaiting_verification_screen.dart';
import 'package:fast_hostel_system/providers/auth_provider.dart';
import 'package:fast_hostel_system/services/auth_service.dart';
import 'package:fast_hostel_system/models/user_model.dart';

class FakeAuthService extends AuthService {
  bool verified = false;
  int sendCount = 0;
  @override
  Future<void> sendEmailVerification() async {
    sendCount++;
  }

  @override
  Future<bool> isEmailVerified() async {
    return verified;
  }

  @override
  Future<UserModel?> getUser(String uid) async {
    // return a simple UserModel matching the uid
    return UserModel(
      uid: uid,
      name: 'Test User',
      email: 'student@university.edu.pk',
      phone: '03001234567',
      gender: Gender.male,
      arnRollNumber: 'ARN123',
      fathersName: 'Father',
      year: '2024',
      status: 'active',
      role: UserRole.student,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> signOut() async {
    // no-op for test
  }

  // The rest of the AuthService API is not used in these tests; provide
  // minimal implementations to satisfy the interface.
  @override
  User? get currentUser => null;

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  bool isValidUniversityEmail(String email) => true;

  @override
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
    throw UnimplementedError();
  }

  @override
  Future<UserCredential?> signIn(
      {required String email, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> resetPassword(String email) async {
    throw UnimplementedError();
  }

  @override
  Stream<UserModel?> getUserStream(String uid) => const Stream.empty();

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteUser() async {
    throw UnimplementedError();
  }
}

// Provide an AuthNotifier-compatible notifier for overrides. It accepts any
// AuthService implementation (we'll pass the fake service) so no real
// Firebase initialization is required.
class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier(super.service, UserModel user) {
    // Directly set the state to the provided user to avoid async listeners
    state = AsyncValue.data(user);
  }
}

void main() {
  testWidgets('resend verification calls sendEmailVerification',
      (tester) async {
    final fakeAuth = FakeAuthService();

    final mockUser = UserModel(
      uid: 'testuid',
      name: 'Test',
      email: 'student@university.edu.pk',
      phone: '03001234567',
      gender: Gender.male,
      arnRollNumber: 'ARN1',
      fathersName: 'Dad',
      year: '2024',
      status: 'active',
      role: UserRole.student,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final testNotifierProvider =
        StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>(
            (ref) => TestAuthNotifier(fakeAuth, mockUser));

    final container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(fakeAuth),
      // ignore: deprecated_member_use
      currentUserProvider.overrideWithProvider(testNotifierProvider),
    ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AwaitingVerificationScreen()),
      ),
    );

    // Tap the resend button
    expect(find.text('Resend Verification Email'), findsOneWidget);
    await tester.tap(find.text('Resend Verification Email'));
    await tester.pumpAndSettle();

    expect(fakeAuth.sendCount, 1);
  });

  testWidgets('manual verify navigates to student dashboard when verified',
      (tester) async {
    final fakeAuth = FakeAuthService();
    fakeAuth.verified = true;

    final mockUser = UserModel(
      uid: 'testuid',
      name: 'Test',
      email: 'student@university.edu.pk',
      phone: '03001234567',
      gender: Gender.male,
      arnRollNumber: 'ARN1',
      fathersName: 'Dad',
      year: '2024',
      status: 'active',
      role: UserRole.student,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final testNotifierProvider =
        StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>(
            (ref) => TestAuthNotifier(fakeAuth, mockUser));

    final container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(fakeAuth),
      // ignore: deprecated_member_use
      currentUserProvider.overrideWithProvider(testNotifierProvider),
    ]);

    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, state) => const AwaitingVerificationScreen()),
      GoRoute(
          path: '/student/dashboard',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('STUDENT DASHBOARD')))),
    ], initialLocation: '/');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // Tap 'I have verified' button
    expect(find.text('I have verified'), findsOneWidget);
    await tester.tap(find.text('I have verified'));
    await tester.pumpAndSettle();

    // Should navigate to student dashboard
    expect(find.text('STUDENT DASHBOARD'), findsOneWidget);
  });
}
