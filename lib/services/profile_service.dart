import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_model.dart';
import 'cloudinary_service.dart';

final profileServiceProvider = Provider((ref) => ProfileService());

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user profile
  Future<ProfileModel?> getProfile(String userId) async {
    try {
      final doc = await _firestore.collection('profiles').doc(userId).get();
      if (doc.exists) {
        return ProfileModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('profiles').doc(userId).update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> uploadProfileImage(String userId, Object? imageFile) async {
    try {
      final imageUrl = await CloudinaryService.uploadImage(file: imageFile);
      if (imageUrl == null) {
        throw Exception('Profile image upload cancelled');
      }
      return imageUrl;
    } catch (e) {
      rethrow;
    }
  }

  // Update user preferences
  Future<void> updatePreferences(
      String userId, Map<String, dynamic> preferences) async {
    try {
      await _firestore.collection('profiles').doc(userId).update({
        'preferences': preferences,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Create new profile
  Future<void> createProfile(ProfileModel profile) async {
    try {
      await _firestore
          .collection('profiles')
          .doc(profile.id)
          .set(profile.toMap());
    } catch (e) {
      rethrow;
    }
  }
}
