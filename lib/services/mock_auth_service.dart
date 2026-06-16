import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

class MockAuthService {
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    // Mock login - accept any email/password for demo
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    if (email.isNotEmpty && password.isNotEmpty) {
      _currentUser = UserModel(
        uid: 'mock_user_123',
        name: email.split('@')[0],
        email: email,
        phone: '03001234567',
        gender: Gender.male,
        arnRollNumber: 'ARN123456',
        fathersName: 'Mock Father',
        year: '2024',
        status: 'active',
        role: UserRole.student,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return _currentUser;
    }

    throw Exception('Invalid credentials');
  }

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required String fathersName,
    required String arnRollNumber,
    required String phone,
    required Gender gender,
    required String year,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    // Validate required fields
    if (email.isEmpty || password.isEmpty || name.isEmpty || 
        fathersName.isEmpty || arnRollNumber.isEmpty || 
        phone.isEmpty || year.isEmpty) {
      throw Exception('All fields are required');
    }

    // Validate email format
    if (!email.endsWith('@university.edu.pk')) {
      throw Exception('Must use university email');
    }

    _currentUser = UserModel(
      uid: 'mock_user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      phone: phone,
      gender: gender,
      arnRollNumber: arnRollNumber,
      fathersName: fathersName,
      year: year,
      status: 'active',
      role: UserRole.student,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return _currentUser;
  }

  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await Future.delayed(const Duration(seconds: 1));
    // Mock password reset
  }
}

final mockAuthServiceProvider = Provider<MockAuthService>((ref) => MockAuthService());



