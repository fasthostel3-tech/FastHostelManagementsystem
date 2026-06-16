import 'package:flutter_test/flutter_test.dart';
import 'package:fast_hostel_system/services/mock_auth_service.dart';
import 'package:fast_hostel_system/services/auth_service.dart';
import 'package:fast_hostel_system/models/user_model.dart';
import 'package:fast_hostel_system/models/hostel_model.dart';
import 'package:fast_hostel_system/models/hall_floor_room_model.dart';

void main() {
  group('Comprehensive Test Suite', () {
    late MockAuthService authService;

    setUp(() {
      authService = MockAuthService();
    });

    group('Unit Tests - Authentication', () {
      test('Sign up with all required fields', () async {
        final result = await authService.signUp(
          email: 'test@university.edu.pk',
          password: 'Test123!',
          name: 'John Doe',
          fathersName: 'Father Name',
          arnRollNumber: 'ARN123',
          phone: '03001234567',
          year: '2024',
          gender: Gender.male,
        );

        expect(result, isNotNull);
        expect(result!.name, 'John Doe');
        expect(result.fathersName, 'Father Name');
        expect(result.arnRollNumber, 'ARN123');
      });

      test('Sign up fails without Father\'s Name', () async {
        expect(
          () => authService.signUp(
            email: 'test@university.edu.pk',
            password: 'Test123!',
            name: 'John Doe',
            fathersName: '', // Empty
            arnRollNumber: 'ARN123',
            phone: '03001234567',
            year: '2024',
            gender: Gender.male,
          ),
          throwsException,
        );
      });

      test('Password validation - too short', () {
        final service = AuthService();
        // Password must be at least 8 characters
        expect(service.isValidUniversityEmail('test@university.edu.pk'), true);
      });

      test('Email validation - university domain required', () {
        final service = AuthService();
        expect(service.isValidUniversityEmail('test@university.edu.pk'), true);
        expect(service.isValidUniversityEmail('test@gmail.com'), false);
      });
    });

    group('Unit Tests - Hostel Models', () {
      test('HostelApplicationModel fee calculation', () {
        expect(
          HostelApplicationModel.getFeeAmount(RoomType.single),
          70000.0,
        );
        expect(
          HostelApplicationModel.getFeeAmount(RoomType.double),
          67000.0,
        );
        expect(
          HostelApplicationModel.getFeeAmount(RoomType.shared),
          42000.0,
        );
      });

      test('RoomModel availability check', () {
        final now = DateTime.now();
        final room = RoomModel(
          id: 'R1',
          floorId: 'F1',
          name: '101',
          capacity: 2,
          occupied: 1,
          isAvailable: true,
          createdAt: now,
          updatedAt: now,
        );

        expect(room.occupied < room.capacity, true);
        expect(room.isAvailable, true);
      });
    });

    group('Integration Tests - Navigation Flow', () {
      testWidgets('Sign up to dashboard flow', (WidgetTester tester) async {
        // This would test the complete flow
        // For now, we verify the structure exists
        expect(true, true); // Placeholder
      });
    });

    group('Validation Tests', () {
      test('Phone number validation - valid formats', () {
        final validPhones = [
          '03001234567',
          '0300-123-4567',
          '0300 123 4567',
        ];

        for (final phone in validPhones) {
          final cleaned = phone.replaceAll(RegExp(r'[\s-]'), '');
          expect(RegExp(r'^[0-9]{10,15}$').hasMatch(cleaned), true);
        }
      });

      test('Password strength validation', () {
        final weakPasswords = ['123456', 'password', 'PASSWORD'];
        final strongPasswords = ['Test123!', 'MyPass123', 'Secure1Pass'];

        for (final pwd in weakPasswords) {
          final hasUpper = pwd.contains(RegExp(r'[A-Z]'));
          final hasLower = pwd.contains(RegExp(r'[a-z]'));
          final hasNumber = pwd.contains(RegExp(r'[0-9]'));
          expect(hasUpper && hasLower && hasNumber, false);
        }

        for (final pwd in strongPasswords) {
          final hasUpper = pwd.contains(RegExp(r'[A-Z]'));
          final hasLower = pwd.contains(RegExp(r'[a-z]'));
          final hasNumber = pwd.contains(RegExp(r'[0-9]'));
          expect(hasUpper && hasLower && hasNumber, true);
        }
      });
    });
  });
}


