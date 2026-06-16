import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notice_model.dart';

final noticeBoardServiceProvider = Provider((ref) => NoticeBoardService());

class NoticeBoardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all active notices (for students)
  Stream<List<NoticeModel>> getActiveNotices() {
    return _firestore
        .collection('noticeBoard')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          // Filter isActive in memory to avoid composite index requirement
          return snapshot.docs
              .where((doc) {
                final data = doc.data();
                return data['isActive'] == true;
              })
              .map((doc) => NoticeModel.fromFirestore(doc))
              .toList();
        });
  }

  // Get all notices (for admin)
  Stream<List<NoticeModel>> getAllNotices() {
    return _firestore
        .collection('noticeBoard')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NoticeModel.fromFirestore(doc))
            .toList());
  }

  // Create a new notice (admin only)
  Future<String> createNotice({
    required String title,
    required String message,
    String? postedBy,
  }) async {
    try {
      final noticeId = _firestore.collection('noticeBoard').doc().id;
      final notice = NoticeModel(
        id: noticeId,
        title: title,
        message: message,
        postedBy: postedBy,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection('noticeBoard')
          .doc(noticeId)
          .set(notice.toFirestore());

      return noticeId;
    } catch (e) {
      throw Exception('Failed to create notice: $e');
    }
  }

  // Update a notice (admin only)
  Future<void> updateNotice({
    required String noticeId,
    String? title,
    String? message,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) updates['title'] = title;
      if (message != null) updates['message'] = message;
      if (isActive != null) updates['isActive'] = isActive;

      await _firestore.collection('noticeBoard').doc(noticeId).update(updates);
    } catch (e) {
      throw Exception('Failed to update notice: $e');
    }
  }

  // Delete a notice (admin only)
  Future<void> deleteNotice(String noticeId) async {
    try {
      await _firestore.collection('noticeBoard').doc(noticeId).delete();
    } catch (e) {
      throw Exception('Failed to delete notice: $e');
    }
  }
}

