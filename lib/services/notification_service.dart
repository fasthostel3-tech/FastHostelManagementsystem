import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final notificationServiceProvider = Provider((ref) => NotificationService());

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Global notifications collection (for admin/broadcast)
  CollectionReference<Map<String, dynamic>> get _globalNotificationsCollection =>
      _firestore.collection('notifications');
  
  // User-specific notifications subcollection
  CollectionReference<Map<String, dynamic>> _userNotificationsCollection(String userId) =>
      _firestore.collection('profiles').doc(userId).collection('notifications');

  // Initialize notifications
  Future<void> initialize() async {
    // Request permission for notifications
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    String? token = await _messaging.getToken();
    if (token != null) {
      // ignore: avoid_print
      debugPrint('FCM Token: $token');
      // Store token in user's profile so Cloud Function can send push to that token
      // nothing else here; persisted by auth flow when available
      // Note: storing token requires user's uid; the app should write it to profiles
      // We'll provide a helper write below (best-effort) using the current auth user id if available
      // We intentionally avoid writing to Firestore here to prevent circular imports
      // The Auth flow should call NotificationService.saveTokenForUser(uid, token)
    }
  }

  /// Return the current FCM token for this device (may be null)
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Failed to get FCM token: $e');
      return null;
    }
  }

  /// Save the FCM token for a user. This writes to `profiles/{uid}.fcmTokens` (array union).
  Future<void> saveTokenForUser(String uid, String token) async {
    try {
      final profilesRef = _firestore.collection('profiles').doc(uid);
      await profilesRef.set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Failed to save FCM token for $uid: $e');
    }
  }

  // Get user notifications (from user subcollection to avoid composite index)
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _userNotificationsCollection(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList());
  }

  // Create notification (writes to both global and user subcollection)
  Future<void> createNotification(NotificationModel notification) async {
    try {
      final notificationId = _globalNotificationsCollection.doc().id;
      final data = notification.toMap();
      
      // Write to both global collection and user subcollection
      final batch = _firestore.batch();
      batch.set(_globalNotificationsCollection.doc(notificationId), data);
      batch.set(_userNotificationsCollection(notification.userId).doc(notificationId), data);
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Mark notification as read (update both collections)
  Future<void> markAsRead(String notificationId) async {
    try {
      // Get notification to find userId
      final doc = await _globalNotificationsCollection.doc(notificationId).get();
      final data = doc.data();
      final userId = data?['userId'] as String?;

      // Update both collections
      final batch = _firestore.batch();
      batch.update(_globalNotificationsCollection.doc(notificationId), {'isRead': true});
      if (userId != null) {
        batch.update(_userNotificationsCollection(userId).doc(notificationId), {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Delete notification (delete from both collections)
  Future<void> deleteNotification(String notificationId) async {
    try {
      // Get notification to find userId
      final doc = await _globalNotificationsCollection.doc(notificationId).get();
      final data = doc.data();
      final userId = data?['userId'] as String?;

      // Delete from both collections
      final batch = _firestore.batch();
      batch.delete(_globalNotificationsCollection.doc(notificationId));
      if (userId != null) {
        batch.delete(_userNotificationsCollection(userId).doc(notificationId));
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}