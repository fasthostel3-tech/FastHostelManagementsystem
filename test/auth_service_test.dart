import 'package:flutter_test/flutter_test.dart';
import 'package:fast_hostel_system/services/mock_auth_service.dart';

void main() {
  late MockAuthService authService;

  setUp(() {
    authService = MockAuthService();
  });

  group('Authentication Tests', () {
    test('signIn returns user for valid credentials', () async {
      final result = await authService.signIn(
        email: 'test@university.edu.pk',
        password: 'Test123!',
      );
      
      expect(result, isNotNull);
      expect(result!.email, 'test@university.edu.pk');
    });

    test('signIn fails for invalid credentials', () async {
      expect(
        () => authService.signIn(
          email: '',
          password: '',
        ),
        throwsException,
      );
    });

    test('signOut clears current user', () async {
      // First sign in
      await authService.signIn(
        email: 'test@university.edu.pk',
        password: 'Test123!',
      );
      
      // Verify user is logged in
      expect(authService.isLoggedIn, true);
      
      // Then sign out
      await authService.signOut();
      
      // User should be logged out
      expect(authService.isLoggedIn, false);
      expect(authService.currentUser, isNull);
    });
  });
}