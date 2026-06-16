import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../platform_io.dart';
import 'cloudinary_service.dart';

final chatServiceProvider = Provider((ref) => ChatService());

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of chat rooms the given user participates in.
  Stream<List<ChatRoom>> getChatRooms(String userId) {
    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snap) {
      final rooms =
          snap.docs.map((d) => ChatRoom.fromFirestore(d)).toList();
      rooms.sort((a, b) {
        final aTime = a.lastMessageTime ?? DateTime(2020);
        final bTime = b.lastMessageTime ?? DateTime(2020);
        return bTime.compareTo(aTime);
      });
      return rooms;
    });
  }

  /// Stream of messages in a chat room, newest first.
  Stream<List<ChatMessage>> getChatMessages(String roomId) {
    return _firestore
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }

  /// Send a text or image message to a room.
  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String content,
    File? image,
  }) async {
    String? imageUrl;
    if (image != null) {
      imageUrl = await CloudinaryService.uploadImage(file: image);
    }

    final now = DateTime.now();
    final messageData = {
      'senderId': senderId,
      'content': content,
      'timestamp': Timestamp.fromDate(now),
      'imageUrl': imageUrl,
      'isRead': false,
    };

    final batch = _firestore.batch();

    // Add message to subcollection
    final msgRef = _firestore
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .doc();
    batch.set(msgRef, messageData);

    // Update room metadata and bump unread counts for all other participants
    final roomRef = _firestore.collection('chatRooms').doc(roomId);
    final roomSnap = await roomRef.get();
    final participants =
        List<String>.from(roomSnap.data()?['participants'] ?? []);

    final unreadUpdates = <String, dynamic>{
      'lastMessage': content,
      'lastMessageTime': Timestamp.fromDate(now),
    };
    for (final p in participants) {
      if (p != senderId) {
        unreadUpdates['unreadCount.$p'] = FieldValue.increment(1);
      }
    }
    batch.update(roomRef, unreadUpdates);

    await batch.commit();
  }

  /// Mark all messages in a room as read for the given user.
  Future<void> markAsRead(String roomId, String userId) async {
    await _firestore.collection('chatRooms').doc(roomId).update({
      'unreadCount.$userId': 0,
    });
  }

  /// Create a new chat room between two users.
  Future<String> createChatRoom({
    required List<String> participants,
    required String name,
    String? imageUrl,
  }) async {
    final doc = await _firestore.collection('chatRooms').add({
      'participants': participants,
      'name': name,
      'imageUrl': imageUrl,
      'lastMessage': null,
      'lastMessageTime': null,
      'unreadCount': {for (final p in participants) p: 0},
    });
    return doc.id;
  }
}
