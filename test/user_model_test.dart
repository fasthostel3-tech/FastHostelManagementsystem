import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_hostel_system/models/user_model.dart';

void main() {
  group('UserModel Tests', () {
    final now = DateTime.now();
    late Map<String, dynamic> validUserData;

    setUp(() {
      validUserData = {
        'name': 'Test User',
        'email': 'test@university.edu.pk',
        'phone': '03001234567',
        'gender': 'male',
        'arnRollNumber': 'ARN123',
        'fathersName': 'Test Father',
        'year': '2024',
        'status': 'active',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };
    });

    test('UserModel creation with valid data', () {
      final user = UserModel(
        uid: 'test123',
        name: 'Test User',
        email: 'test@university.edu.pk',
        phone: '03001234567',
        gender: Gender.male,
        arnRollNumber: 'ARN123',
        fathersName: 'Test Father',
        year: '2024',
        status: 'active',
        role: UserRole.student,
        createdAt: now,
        updatedAt: now,
      );

      expect(user.uid, 'test123');
      expect(user.name, 'Test User');
      expect(user.email, 'test@university.edu.pk');
      expect(user.phone, '03001234567');
      expect(user.gender, Gender.male);
      expect(user.arnRollNumber, 'ARN123');
      expect(user.fathersName, 'Test Father');
      expect(user.year, '2024');
      expect(user.status, 'active');
      expect(user.createdAt, now);
      expect(user.updatedAt, now);
    });

    test('UserModel fromMap creates correct object', () {
      final user = UserModel.fromMap(validUserData, uid: 'test123');
      
      expect(user.uid, 'test123');
      expect(user.name, validUserData['name']);
      expect(user.email, validUserData['email']);
      expect(user.phone, validUserData['phone']);
      expect(user.gender, Gender.male);
      expect(user.arnRollNumber, validUserData['arnRollNumber']);
      expect(user.fathersName, validUserData['fathersName']);
      expect(user.year, validUserData['year']);
      expect(user.status, validUserData['status']);
    });

    test('UserModel handles missing optional fields', () {
      final minimalData = {
        'name': 'Test User',
        'email': 'test@university.edu.pk',
        'gender': 'male',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final user = UserModel.fromMap(minimalData, uid: 'test123');
      expect(user.uid, 'test123');
      expect(user.name, 'Test User');
      expect(user.email, 'test@university.edu.pk');
      expect(user.phone, '');
      expect(user.gender, Gender.male);
      expect(user.arnRollNumber, '');
      expect(user.fathersName, '');
      expect(user.year, '');
      expect(user.status, 'active');
    });

    test('UserModel stores provided email without validation', () {
      final user = UserModel(
        uid: 'test123',
        name: 'Test User',
        email: 'invalid-email',
        phone: '03001234567',
        gender: Gender.male,
        arnRollNumber: 'ARN123',
        fathersName: 'Test Father',
        year: '2024',
        status: 'active',
        role: UserRole.student,
        createdAt: now,
        updatedAt: now,
      );

      expect(user.email, 'invalid-email');
    });
  });
}