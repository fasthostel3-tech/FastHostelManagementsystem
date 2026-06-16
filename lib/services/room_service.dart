import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room_model.dart';

final roomServiceProvider = Provider((ref) => RoomService());

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all rooms
  Stream<List<RoomModel>> getAllRooms() {
    return _firestore.collection('rooms').orderBy('number').snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) => RoomModel.fromFirestore(doc)).toList());
  }

  // Get available rooms
  Stream<List<RoomModel>> getAvailableRooms() {
    return _firestore
        .collection('rooms')
        .where('status', isEqualTo: RoomStatus.available.toString())
        .orderBy('number')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RoomModel.fromFirestore(doc)).toList());
  }

  // Get room by ID
  Future<RoomModel?> getRoomById(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (doc.exists) {
        return RoomModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get rooms by floor
  Stream<List<RoomModel>> getRoomsByFloor(int floor) {
    return _firestore
        .collection('rooms')
        .where('floor', isEqualTo: floor)
        .orderBy('number')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RoomModel.fromFirestore(doc)).toList());
  }

  // Allocate room to student
  Future<void> allocateRoom(String roomId, String studentId) async {
    try {
      final room = await getRoomById(roomId);
      if (room == null) {
        throw Exception('Room not found');
      }

      if (!room.isAvailable || room.isFull) {
        throw Exception('Room is not available for allocation');
      }

      final batch = _firestore.batch();
      final roomRef = _firestore.collection('rooms').doc(roomId);

      // Update room
      batch.update(roomRef, {
        'occupants': FieldValue.arrayUnion([studentId]),
        'occupiedCount': FieldValue.increment(1),
        'status': room.capacity == room.occupiedCount + 1
            ? RoomStatus.occupied.toString()
            : RoomStatus.available.toString(),
      });

      // Update student profile
      final studentRef = _firestore.collection('profiles').doc(studentId);
      batch.update(studentRef, {
        'roomNumber': room.number,
        'roomId': roomId,
      });

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Deallocate room from student
  Future<void> deallocateRoom(String roomId, String studentId) async {
    try {
      final batch = _firestore.batch();
      final roomRef = _firestore.collection('rooms').doc(roomId);

      batch.update(roomRef, {
        'occupants': FieldValue.arrayRemove([studentId]),
        'occupiedCount': FieldValue.increment(-1),
        'status': RoomStatus.available.toString(),
      });

      final studentRef = _firestore.collection('profiles').doc(studentId);
      batch.update(studentRef, {
        'roomNumber': FieldValue.delete(),
        'roomId': FieldValue.delete(),
      });

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Update room status
  Future<void> updateRoomStatus(String roomId, RoomStatus status) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .update({'status': status.toString()});
    } catch (e) {
      rethrow;
    }
  }

  // Get room occupants details
  // If includePrivateInfo is false (default) returns a limited public summary
  // If includePrivateInfo is true returns full profile data (admin use)
  Future<List<Map<String, dynamic>>> getRoomOccupantsDetails(String roomId,
      {bool includePrivateInfo = false}) async {
    try {
      final room = await getRoomById(roomId);
      if (room == null) {
        throw Exception('Room not found');
      }

      final occupantsData = await Future.wait(
        room.occupants.map((studentId) async {
          final doc =
              await _firestore.collection('profiles').doc(studentId).get();
          final data = doc.data();
          if (data == null) return <String, dynamic>{'id': studentId};

          if (includePrivateInfo) {
            // Admin: return full profile
            return data;
          } else {
            // Student: return limited public info only
            final name = (data['name'] as String?) ?? '';
            return {
              'id': studentId,
              'initials': name.isNotEmpty
                  ? name
                      .split(' ')
                      .map((s) => s.isNotEmpty ? s[0] : '')
                      .take(2)
                      .join()
                  : '',
              'hasProfileImage': data['profileImage'] != null,
            };
          }
        }),
      );

      return occupantsData.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      rethrow;
    }
  }

  // Search rooms
  Stream<List<RoomModel>> searchRooms({
    RoomType? type,
    int? floor,
    double? maxPrice,
    bool? onlyAvailable,
  }) {
    Query query = _firestore.collection('rooms');

    if (type != null) {
      query = query.where('type', isEqualTo: type.toString());
    }

    if (floor != null) {
      query = query.where('floor', isEqualTo: floor);
    }

    if (maxPrice != null) {
      query = query.where('price', isLessThanOrEqualTo: maxPrice);
    }

    if (onlyAvailable == true) {
      query = query.where('status', isEqualTo: RoomStatus.available.toString());
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => RoomModel.fromFirestore(doc)).toList());
  }
}
