import 'package:cloud_firestore/cloud_firestore.dart';

enum Gender { male, female }
enum UserRole { student, admin }

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final Gender gender;
  final String arnRollNumber;
  final String fathersName;
  final String year;
  final String status;
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? accommodationCooldownUntil;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.gender,
    required this.arnRollNumber,
    required this.fathersName,
    required this.year,
    required this.status,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.accommodationCooldownUntil,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, uid: doc.id);
  }

  /// Creates a UserModel from Firestore data map.
  /// Handles missing or null fields gracefully with default values.
  /// - Missing Timestamp fields default to current DateTime
  /// - Missing string fields default to empty strings
  /// - Missing gender defaults to male
  /// - Missing status defaults to 'active'
  factory UserModel.fromMap(Map<String, dynamic> data, {required String uid}) {
    // Helper function to safely convert Timestamp to DateTime
    DateTime parseTimestamp(dynamic value, {DateTime? defaultValue}) {
      if (value == null) {
        return defaultValue ?? DateTime.now();
      }
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      // If value is not a Timestamp or DateTime, use default
      return defaultValue ?? DateTime.now();
    }

    // Extract email from Firebase Auth if not in Firestore data
    // This ensures email is always available even if document only has FCM token
    final email = data['email'] ?? '';
    
    DateTime? parseTimestampNullable(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      email: email,
      phone: data['phone'] ?? '',
      gender: Gender.values.firstWhere(
        (e) => e.toString() == 'Gender.${data['gender']}',
        orElse: () => Gender.male,
      ),
      arnRollNumber: data['arnRollNumber'] ?? '',
      fathersName: data['fathersName'] ?? '',
      year: data['year'] ?? '',
      status: data['status'] ?? 'active',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${data['role'] ?? 'student'}',
        orElse: () => UserRole.student,
      ),
      // Handle null or missing Timestamp fields gracefully
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
      accommodationCooldownUntil:
          parseTimestampNullable(data['accommodationCooldownUntil']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'gender': gender.toString().split('.').last,
      'arnRollNumber': arnRollNumber,
      'fathersName': fathersName,
      'year': year,
      'status': status,
      'role': role.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (accommodationCooldownUntil != null)
        'accommodationCooldownUntil':
            Timestamp.fromDate(accommodationCooldownUntil!),
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    Gender? gender,
    String? arnRollNumber,
    String? fathersName,
    String? year,
    String? status,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? accommodationCooldownUntil,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      arnRollNumber: arnRollNumber ?? this.arnRollNumber,
      fathersName: fathersName ?? this.fathersName,
      year: year ?? this.year,
      status: status ?? this.status,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      accommodationCooldownUntil:
          accommodationCooldownUntil ?? this.accommodationCooldownUntil,
    );
  }
}


