import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/maintenance_model.dart';
import 'cloudinary_service.dart';

final maintenanceServiceProvider = Provider((ref) => MaintenanceService());

class MaintenanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create maintenance request
  Future<String> createMaintenanceRequest({
    required String userId,
    required String roomNumber,
    required String issue,
    required String description,
    List<Object>? images,
  }) async {
    try {
      // Upload images if provided
      List<String> imageUrls = [];
      if (images != null && images.isNotEmpty) {
        imageUrls = await Future.wait(
          images.map((image) => _uploadImage(image)),
        );
      }

      // Create maintenance request document
      final request = MaintenanceRequest(
        id: '', // Will be set by Firestore
        userId: userId,
        roomNumber: roomNumber,
        issue: issue,
        description: description,
        status: MaintenanceStatus.pending,
        createdAt: DateTime.now(),
        images: imageUrls,
      );

      final docRef = await _firestore
          .collection('maintenance_requests')
          .add(request.toMap());

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // Get maintenance requests for a user
  Stream<List<MaintenanceRequest>> getUserRequests(String userId) {
    return _firestore
        .collection('maintenance_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceRequest.fromFirestore(doc))
            .toList());
  }

  // Get all maintenance requests (for admin)
  Stream<List<MaintenanceRequest>> getAllRequests() {
    return _firestore
        .collection('maintenance_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceRequest.fromFirestore(doc))
            .toList());
  }

  // Update maintenance request status
  Future<void> updateRequestStatus(
    String requestId,
    MaintenanceStatus status, {
    String? staffNotes,
  }) async {
    try {
      await _firestore
          .collection('maintenance_requests')
          .doc(requestId)
          .update({
        'status': status.toString(),
        'resolvedAt': status == MaintenanceStatus.completed
            ? Timestamp.fromDate(DateTime.now())
            : null,
        if (staffNotes != null) 'staffNotes': staffNotes,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _uploadImage(Object? image) async {
    try {
      final url = await CloudinaryService.uploadImage(file: image);
      if (url == null) throw Exception('Image upload cancelled');
      return url;
    } catch (e) {
      rethrow;
    }
  }

  // Delete maintenance request
  Future<void> deleteRequest(String requestId) async {
    try {
      await _firestore
          .collection('maintenance_requests')
          .doc(requestId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }
}
