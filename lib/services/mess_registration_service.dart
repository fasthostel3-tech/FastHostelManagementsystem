import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';
import 'local_notification_service.dart';

final messRegistrationServiceProvider = Provider((ref) => MessRegistrationService());

class MessRegistrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _userMessRegistrations(String studentId) =>
      _firestore.collection('profiles').doc(studentId).collection('messRegistrations');

  Future<void> _syncRegistrationToProfile({
    required String studentId,
    required String registrationId,
    required Map<String, dynamic> data,
  }) async {
    if (studentId.isEmpty) return;
    await _userMessRegistrations(studentId)
        .doc(registrationId)
        .set(data, SetOptions(merge: true));
  }

  /// Register a student for mess service
  Future<String> registerForMess({
    required String studentId,
    required String studentName,
    required String studentEmail,
  }) async {
    try {
      // Check if student already has an active registration
      final existingReg = await _firestore
          .collection('messRegistrations')
          .where('studentId', isEqualTo: studentId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (existingReg.docs.isNotEmpty) {
        throw Exception('You already have an active mess registration');
      }

      // Create new registration
      final registrationId = _firestore.collection('messRegistrations').doc().id;
      final registrationDate = DateTime.now();
      final expiryDate = registrationDate.add(const Duration(days: 365)); // 1 year validity

      final registrationData = {
        'studentId': studentId,
        'studentName': studentName,
        'studentEmail': studentEmail,
        'status': 'pending', // Requires admin approval
        'registrationDate': Timestamp.fromDate(registrationDate),
        'expiryDate': Timestamp.fromDate(expiryDate),
        'createdAt': Timestamp.fromDate(registrationDate),
        'updatedAt': Timestamp.fromDate(registrationDate),
        'id': registrationId,
      };

      await _firestore
          .collection('messRegistrations')
          .doc(registrationId)
          .set(registrationData);
      await _syncRegistrationToProfile(
        studentId: studentId,
        registrationId: registrationId,
        data: registrationData,
      );

      // Notify admin
      try {
        final notification = NotificationModel(
          id: '',
          userId: 'admin',
          title: 'New Mess Registration',
          message: '$studentName has requested mess registration',
          type: 'mess_registration',
          isRead: false,
          createdAt: DateTime.now(),
          data: {'registrationId': registrationId},
        );
        await NotificationService().createNotification(notification);
        await LocalNotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: notification.title,
          body: notification.message,
        );
      } catch (_) {}

      return registrationId;
    } catch (e) {
      throw Exception('Failed to register for mess: $e');
    }
  }

  /// Get user's mess registration
  Stream<Map<String, dynamic>?> getUserMessRegistration(String studentId) {
    return _firestore
        .collection('messRegistrations')
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.data();
    });
  }

  /// Get all mess registrations (admin)
  Stream<List<Map<String, dynamic>>> getAllMessRegistrations() {
    return _firestore
        .collection('messRegistrations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Approve mess registration (admin)
  Future<void> approveRegistration(String registrationId) async {
    try {
      final docRef = _firestore.collection('messRegistrations').doc(registrationId);
      final doc = await docRef.get();
      if (!doc.exists) {
        throw Exception('Registration not found');
      }

      final data = doc.data()!;
      final studentId = data['studentId'] as String?;

      final updates = {
        'status': 'active',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.update(updates);

      if (studentId != null && studentId.isNotEmpty) {
        await _syncRegistrationToProfile(
          studentId: studentId,
          registrationId: registrationId,
          data: updates,
        );

        const message = 'Your mess registration has been approved. You can now use the mess facilities.';
        final notification = NotificationModel(
          id: '',
          userId: studentId,
          title: 'Mess Registration Approved',
          message: message,
          type: 'mess_approved',
          isRead: false,
          createdAt: DateTime.now(),
          data: {'registrationId': registrationId},
        );
        try {
          await NotificationService().createNotification(notification);
          await LocalNotificationService.showNotification(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title: notification.title,
            body: notification.message,
          );
        } catch (_) {}
      }
    } catch (e) {
      throw Exception('Failed to approve registration: $e');
    }
  }

  /// Reject mess registration (admin)
  Future<void> rejectRegistration(String registrationId, {String? reason}) async {
    try {
      final docRef = _firestore.collection('messRegistrations').doc(registrationId);
      final doc = await docRef.get();
      if (!doc.exists) {
        throw Exception('Registration not found');
      }

      final data = doc.data()!;
      final studentId = data['studentId'] as String?;

      final updates = {
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
      };

      await docRef.update(updates);

      if (studentId != null && studentId.isNotEmpty) {
        await _syncRegistrationToProfile(
          studentId: studentId,
          registrationId: registrationId,
          data: updates,
        );

        final message = reason != null && reason.isNotEmpty
            ? 'Your mess registration has been rejected. Reason: $reason'
            : 'Your mess registration has been rejected.';
        final notification = NotificationModel(
          id: '',
          userId: studentId,
          title: 'Mess Registration Rejected',
          message: message,
          type: 'mess_rejected',
          isRead: false,
          createdAt: DateTime.now(),
          data: {'registrationId': registrationId},
        );
        try {
          await NotificationService().createNotification(notification);
          await LocalNotificationService.showNotification(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title: notification.title,
            body: notification.message,
          );
        } catch (_) {}
      }
    } catch (e) {
      throw Exception('Failed to reject registration: $e');
    }
  }

  /// Note: Mess registration cannot be cancelled by students once approved
  /// This is intentional - once a student is registered for mess, they cannot undo it
  /// Only admin can reject or deactivate registrations

  /// Clear all mess registrations (admin only - sets all to rejected)
  Future<void> clearAllRegistrations() async {
    try {
      // Get all registrations
      final registrations = await _firestore
          .collection('messRegistrations')
          .where('status', isEqualTo: 'active')
          .get();

      // Batch update all active registrations to rejected
      final batch = _firestore.batch();
      for (final doc in registrations.docs) {
        final data = doc.data();
        final studentId = data['studentId'] as String?;
        
        // Update main collection
        batch.update(doc.reference, {
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'rejectionReason': 'All registrations cleared by admin',
        });

        // Update user profile subcollection if studentId exists
        if (studentId != null && studentId.isNotEmpty) {
          final userRegRef = _userMessRegistrations(studentId).doc(doc.id);
          batch.set(userRegRef, {
            'status': 'rejected',
            'rejectedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'rejectionReason': 'All registrations cleared by admin',
          }, SetOptions(merge: true));
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to clear mess registrations: $e');
    }
  }
}




