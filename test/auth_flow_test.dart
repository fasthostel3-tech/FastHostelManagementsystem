import 'package:flutter_test/flutter_test.dart';
import 'package:fast_hostel_system/services/mock_auth_service.dart';
import 'package:fast_hostel_system/models/user_model.dart';

void main() {
  late MockAuthService authService;

  setUp(() {
    authService = MockAuthService();
  });

  group('Authentication Flow Tests', () {
    test('Complete signup flow succeeds with valid data', () async {
      final result = await authService.signUp(
        email: 'test@university.edu.pk',
        password: 'Test123!',
        name: 'Test User',
        phone: '03001234567',
        arnRollNumber: 'ARN123',
        fathersName: 'Test Father',
        year: '2024',
        gender: Gender.male,
      );
      
      expect(result, isNotNull);
      expect(result!.email, 'test@university.edu.pk');
      expect(result.name, 'Test User');
      expect(result.status, 'active');
    });

    test('Signup fails with non-university email', () async {
      expect(
        () => authService.signUp(
          email: 'test@gmail.com',
          password: 'Test123!',
          name: 'Test User',
          phone: '03001234567',
          arnRollNumber: 'ARN123',
          fathersName: 'Test Father',
          year: '2024',
          gender: Gender.male,
        ),
        throwsException,
      );
    });

    test('Sign in and password reset flow', () async {
      // First sign up
      await authService.signUp(
        email: 'test@university.edu.pk',
        password: 'Test123!',
        name: 'Test User',
        phone: '03001234567',
        arnRollNumber: 'ARN123',
        fathersName: 'Test Father',
        year: '2024',
        gender: Gender.male,
      );

      // Try signing in
      var user = await authService.signIn(
        email: 'test@university.edu.pk',
        password: 'Test123!',
      );
      expect(user, isNotNull);

      // Request password reset
      await authService.sendPasswordResetEmail('test@university.edu.pk');

      // Sign out
      await authService.signOut();
      expect(authService.currentUser, isNull);
    });

    test('Authentication persistence', () async {
      // Sign up a user
      await authService.signUp(
        email: 'test@university.edu.pk',
        password: 'Test123!',
        name: 'Test User',
        phone: '03001234567',
        arnRollNumber: 'ARN123',
        fathersName: 'Test Father',
        year: '2024',
        gender: Gender.male,
      );

      // Current user should be set
      expect(authService.currentUser, isNotNull);
      expect(authService.isLoggedIn, true);

      // Sign out
      await authService.signOut();
      expect(authService.currentUser, isNull);
      expect(authService.isLoggedIn, false);
    });
  });
}