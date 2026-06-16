import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileModel {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String? profileImage;
  final String? roomNumber;
  final bool isActive;
  final DateTime joinDate;
  final Map<String, dynamic>? preferences;

  ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    this.profileImage,
    this.roomNumber,
    required this.isActive,
    required this.joinDate,
    this.preferences,
  });

  factory ProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

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
      return defaultValue ?? DateTime.now();
    }

    return ProfileModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      profileImage: data['profileImage'],
      roomNumber: data['roomNumber'],
      isActive: data['isActive'] ?? true,
      joinDate: parseTimestamp(data['joinDate']),
      preferences: data['preferences'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImage': profileImage,
      'roomNumber': roomNumber,
      'isActive': isActive,
      'joinDate': Timestamp.fromDate(joinDate),
      'preferences': preferences,
    };
  }
}