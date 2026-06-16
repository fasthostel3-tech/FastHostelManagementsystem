import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';
import 'local_notification_service.dart';

final complaintServiceProvider = Provider((ref) => ComplaintService());

class ComplaintService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Global complaints collection (for admin)
  CollectionReference<Map<String, dynamic>> get _globalComplaintsCollection =>
      _firestore.collection('complaints');
  
  // User-specific complaints subcollection
  CollectionReference<Map<String, dynamic>> _userComplaintsCollection(String userId) =>
      _firestore.collection('profiles').doc(userId).collection('complaints');

  Future<String> createComplaint({
    required String userId,
    required String title,
    required String description,
  }) async {
    final complaintId = _firestore.collection('complaints').doc().id;
    final data = {
      'userId': userId,
      'title': title,
      'description': description,
      'status': 'open',
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    };

    // Write to both global collection and user subcollection
    final batch = _firestore.batch();
    batch.set(_globalComplaintsCollection.doc(complaintId), data);
    batch.set(_userComplaintsCollection(userId).doc(complaintId), data);
    await batch.commit();

    // create notification for admin (best-effort)
    try {
      final notification = NotificationModel(
        id: '',
        userId: 'admin',
        title: 'New Complaint',
        message: title,
        type: 'complaint_new',
        isRead: false,
        createdAt: DateTime.now(),
        data: {'complaintId': complaintId},
      );
      await NotificationService().createNotification(notification);
      await LocalNotificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: notification.title,
        body: notification.message,
      );
    } catch (_) {}

    return complaintId;
  }

  Stream<List<Map<String, dynamic>>> getUserComplaints(String userId) {
    // Query user subcollection to avoid composite index requirement
    return _userComplaintsCollection(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final m = Map<String, dynamic>.from(d.data());
              m['id'] = d.id;
              return m;
            }).toList());
  }

  Stream<List<Map<String, dynamic>>> getAllComplaints() {
    return _firestore
        .collection('complaints')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final m = Map<String, dynamic>.from(d.data());
              m['id'] = d.id;
              return m;
            }).toList());
  }

  Future<void> resolveComplaint(String id, {String? adminNote}) async {
    // Get complaint to find userId
    final doc = await _globalComplaintsCollection.doc(id).get();
    final data = doc.data();
    final userId = data?['userId'] as String?;

    final updateData = {
      'status': 'resolved',
      'adminNote': adminNote ?? '',
      'updatedAt': DateTime.now(),
    };

    // Update both global and user subcollection
    final batch = _firestore.batch();
    batch.update(_globalComplaintsCollection.doc(id), updateData);
    if (userId != null) {
      batch.update(_userComplaintsCollection(userId).doc(id), updateData);
    }
    await batch.commit();

    // notify user
    if (data != null && userId != null) {
      final notification = NotificationModel(
        id: '',
        userId: userId,
        title: 'Complaint Resolved',
        message: data['title'] ?? 'Your complaint has been resolved',
        type: 'complaint_resolved',
        isRead: false,
        createdAt: DateTime.now(),
        data: {'complaintId': id},
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
  }

  Future<void> deleteComplaint(String id) async {
    // Get complaint to find userId
    final doc = await _globalComplaintsCollection.doc(id).get();
    final data = doc.data();
    final userId = data?['userId'] as String?;

    // Delete from both collections
    final batch = _firestore.batch();
    batch.delete(_globalComplaintsCollection.doc(id));
    if (userId != null) {
      batch.delete(_userComplaintsCollection(userId).doc(id));
    }
    await batch.commit();
  }
}
