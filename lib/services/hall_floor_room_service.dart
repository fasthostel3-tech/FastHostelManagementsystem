import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/hall_floor_room_model.dart';
import '../models/hostel_model.dart' show HostelModel, HostelApplicationModel, RoomType;

final hallFloorRoomServiceProvider = Provider<HallFloorRoomService>((ref) {
  return HallFloorRoomService();
});

class HallFloorRoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // ==================== HALL MANAGEMENT ====================

  /// Create a hall in a hostel
  Future<String> createHall({
    required String hostelId,
    required String name,
    String? description,
  }) async {
    try {
      final hallId = _uuid.v4();
      final hall = HallModel(
        id: hallId,
        hostelId: hostelId,
        name: name,
        description: description,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('halls').doc(hallId).set(hall.toFirestore());
      return hallId;
    } catch (e) {
      throw Exception('Failed to create hall: $e');
    }
  }

  /// Get all halls for a hostel
  Stream<List<HallModel>> getHallsForHostel(String hostelId) {
    return _firestore
        .collection('halls')
        .where('hostelId', isEqualTo: hostelId)
        .snapshots()
        .map((snapshot) {
          final halls = snapshot.docs
              .map((doc) => HallModel.fromFirestore(doc))
              .toList();
          // Sort in-memory to avoid requiring composite index
          halls.sort((a, b) => a.name.compareTo(b.name));
          return halls;
        });
  }

  /// Get full room path details: room → floor → hall (used by admin to show student selection)
  Future<Map<String, dynamic>?> getRoomFullDetails(String roomId) async {
    try {
      final room = await getRoom(roomId);
      if (room == null) return null;

      final floor = await getFloor(room.floorId);
      if (floor == null) return null;

      final hall = await getHall(floor.hallId);
      if (hall == null) return null;

      // Fetch hostel name
      String hostelName = '';
      try {
        final hostelDoc =
            await _firestore.collection('hostels').doc(hall.hostelId).get();
        hostelName = hostelDoc.data()?['name'] ?? '';
      } catch (_) {}

      return {
        'roomId': room.id,
        'roomName': room.name,
        'capacity': room.capacity,
        'occupied': room.occupied,
        'available': room.capacity - room.occupied,
        'floorId': floor.id,
        'floorName': floor.name,
        'hallId': hall.id,
        'hallName': hall.name,
        'hostelName': hostelName,
      };
    } catch (e) {
      debugPrint('getRoomFullDetails error: $e');
      return null;
    }
  }

  /// Get hall by ID
  Future<HallModel?> getHall(String hallId) async {
    try {
      final doc = await _firestore.collection('halls').doc(hallId).get();
      if (doc.exists) {
        return HallModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get hall: $e');
    }
  }

  /// Update hall
  Future<void> updateHall({
    required String hallId,
    String? name,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;

      await _firestore.collection('halls').doc(hallId).update(updates);
    } catch (e) {
      throw Exception('Failed to update hall: $e');
    }
  }

  /// Delete hall
  Future<void> deleteHall(String hallId) async {
    try {
      // Delete all floors, rooms, and beds in this hall
      final floors = await _firestore
          .collection('floors')
          .where('hallId', isEqualTo: hallId)
          .get();

      for (var floorDoc in floors.docs) {
        await deleteFloor(floorDoc.id);
      }

      await _firestore.collection('halls').doc(hallId).delete();
    } catch (e) {
      throw Exception('Failed to delete hall: $e');
    }
  }

  // ==================== FLOOR MANAGEMENT ====================

  /// Create a floor in a hall
  Future<String> createFloor({
    required String hallId,
    required String name,
    required int floorNumber,
    String? description,
  }) async {
    try {
      final floorId = _uuid.v4();
      final floor = FloorModel(
        id: floorId,
        hallId: hallId,
        name: name,
        floorNumber: floorNumber,
        description: description,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('floors').doc(floorId).set(floor.toFirestore());
      return floorId;
    } catch (e) {
      throw Exception('Failed to create floor: $e');
    }
  }

  /// Get all floors for a hall
  Stream<List<FloorModel>> getFloorsForHall(String hallId) {
    return _firestore
        .collection('floors')
        .where('hallId', isEqualTo: hallId)
        .snapshots()
        .map((snapshot) {
          final floors = snapshot.docs
              .map((doc) => FloorModel.fromFirestore(doc))
              .toList();
          // Sort in-memory by floorNumber to avoid index requirement
          floors.sort((a, b) => a.floorNumber.compareTo(b.floorNumber));
          return floors;
        });
  }

  /// Get floor by ID
  Future<FloorModel?> getFloor(String floorId) async {
    try {
      final doc = await _firestore.collection('floors').doc(floorId).get();
      if (doc.exists) {
        return FloorModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get floor: $e');
    }
  }

  /// Update floor
  Future<void> updateFloor({
    required String floorId,
    String? name,
    int? floorNumber,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) updates['name'] = name;
      if (floorNumber != null) updates['floorNumber'] = floorNumber;
      if (description != null) updates['description'] = description;

      await _firestore.collection('floors').doc(floorId).update(updates);
    } catch (e) {
      throw Exception('Failed to update floor: $e');
    }
  }

  /// Delete floor
  Future<void> deleteFloor(String floorId) async {
    try {
      // Delete all rooms and beds in this floor
      final rooms = await _firestore
          .collection('rooms')
          .where('floorId', isEqualTo: floorId)
          .get();

      for (var roomDoc in rooms.docs) {
        await deleteRoom(roomDoc.id);
      }

      await _firestore.collection('floors').doc(floorId).delete();
    } catch (e) {
      throw Exception('Failed to delete floor: $e');
    }
  }

  // ==================== ROOM MANAGEMENT ====================

  /// Create a room in a floor
  Future<String> createRoom({
    required String floorId,
    required String name,
    required int capacity, // Number of beds
    String? description,
  }) async {
    try {
      final roomId = _uuid.v4();
      final room = RoomModel(
        id: roomId,
        floorId: floorId,
        name: name,
        capacity: capacity,
        occupied: 0,
        isAvailable: true,
        description: description,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('rooms').doc(roomId).set(room.toFirestore());

      // Create beds for this room
      for (int i = 1; i <= capacity; i++) {
        await createBed(
          roomId: roomId,
          bedNumber: 'Bed $i',
        );
      }

      return roomId;
    } catch (e) {
      throw Exception('Failed to create room: $e');
    }
  }

  /// Get all rooms for a floor
  Stream<List<RoomModel>> getRoomsForFloor(String floorId) {
    return _firestore
        .collection('rooms')
        .where('floorId', isEqualTo: floorId)
        .snapshots()
        .map((snapshot) {
          final rooms = snapshot.docs
              .map((doc) => RoomModel.fromFirestore(doc))
              .toList();
          // Sort in-memory by name to avoid index requirement
          rooms.sort((a, b) => a.name.compareTo(b.name));
          return rooms;
        });
  }

  /// Get room by ID
  Future<RoomModel?> getRoom(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (doc.exists) {
        return RoomModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get room: $e');
    }
  }

  /// Update room
  Future<void> updateRoom({
    required String roomId,
    String? name,
    int? capacity,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;

      // If capacity is changed, adjust beds
      if (capacity != null) {
        final room = await getRoom(roomId);
        if (room != null) {
          final currentBeds = await _firestore
              .collection('beds')
              .where('roomId', isEqualTo: roomId)
              .get();

          final currentBedCount = currentBeds.docs.length;

          if (capacity > currentBedCount) {
            // Add more beds
            for (int i = currentBedCount + 1; i <= capacity; i++) {
              await createBed(roomId: roomId, bedNumber: 'Bed $i');
            }
          } else if (capacity < currentBedCount) {
            // Remove beds (only if not occupied)
            final bedsToRemove = currentBeds.docs.skip(capacity).toList();
            for (var bedDoc in bedsToRemove) {
              final bed = BedModel.fromFirestore(bedDoc);
              if (!bed.isOccupied) {
                await _firestore.collection('beds').doc(bedDoc.id).delete();
              }
            }
          }

          updates['capacity'] = capacity;
          // Recalculate occupied count - filter in memory to avoid index requirement
          final allBeds = await _firestore
              .collection('beds')
              .where('roomId', isEqualTo: roomId)
              .get();
          final occupiedBeds = allBeds.docs.where((doc) {
            final data = doc.data();
            return data['isOccupied'] == true;
          }).toList();
          updates['occupied'] = occupiedBeds.length;
          updates['isAvailable'] = occupiedBeds.length < capacity;
        }
      }

      await _firestore.collection('rooms').doc(roomId).update(updates);
    } catch (e) {
      throw Exception('Failed to update room: $e');
    }
  }

  /// Delete room
  Future<void> deleteRoom(String roomId) async {
    try {
      // Delete all beds in this room
      final beds = await _firestore
          .collection('beds')
          .where('roomId', isEqualTo: roomId)
          .get();

      for (var bedDoc in beds.docs) {
        await _firestore.collection('beds').doc(bedDoc.id).delete();
      }

      await _firestore.collection('rooms').doc(roomId).delete();
    } catch (e) {
      throw Exception('Failed to delete room: $e');
    }
  }

  // ==================== BED MANAGEMENT ====================

  /// Create a bed in a room
  Future<String> createBed({
    required String roomId,
    required String bedNumber,
  }) async {
    try {
      final bedId = _uuid.v4();
      final bed = BedModel(
        id: bedId,
        roomId: roomId,
        bedNumber: bedNumber,
        isOccupied: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('beds').doc(bedId).set(bed.toFirestore());
      return bedId;
    } catch (e) {
      throw Exception('Failed to create bed: $e');
    }
  }

  /// Get all beds for a room
  Stream<List<BedModel>> getBedsForRoom(String roomId) {
    return _firestore
        .collection('beds')
        .where('roomId', isEqualTo: roomId)
        .snapshots()
        .map((snapshot) {
          final beds = snapshot.docs
              .map((doc) => BedModel.fromFirestore(doc))
              .toList();
          // Sort in-memory by bedNumber to avoid index requirement
          beds.sort((a, b) => a.bedNumber.compareTo(b.bedNumber));
          return beds;
        });
  }

  /// Assign bed to student
  Future<void> assignBedToStudent({
    required String bedId,
    required String studentId,
  }) async {
    try {
      // Check if student already has a bed assigned
      final existingBeds = await _firestore
          .collection('beds')
          .where('studentId', isEqualTo: studentId)
          .where('isOccupied', isEqualTo: true)
          .get();

      if (existingBeds.docs.isNotEmpty) {
        throw Exception('You already have a bed assigned. You cannot be assigned another bed.');
      }

      final bedDoc = await _firestore.collection('beds').doc(bedId).get();
      if (!bedDoc.exists) {
        throw Exception('Bed not found');
      }

      final bed = BedModel.fromFirestore(bedDoc);
      if (bed.isOccupied) {
        throw Exception('Bed is already occupied');
      }

      // Update bed
      await _firestore.collection('beds').doc(bedId).update({
        'studentId': studentId,
        'isOccupied': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update room occupied count
      final room = await getRoom(bed.roomId);
      if (room != null) {
        final newOccupied = room.occupied + 1;
        await _firestore.collection('rooms').doc(bed.roomId).update({
          'occupied': newOccupied,
          'isAvailable': newOccupied < room.capacity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to assign bed: $e');
    }
  }

  /// Unassign bed from student
  Future<void> unassignBed(String bedId) async {
    try {
      final bedDoc = await _firestore.collection('beds').doc(bedId).get();
      if (!bedDoc.exists) {
        throw Exception('Bed not found');
      }

      final bed = BedModel.fromFirestore(bedDoc);

      // Update bed
      await _firestore.collection('beds').doc(bedId).update({
        'studentId': FieldValue.delete(),
        'isOccupied': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update room occupied count
      final room = await getRoom(bed.roomId);
      if (room != null) {
        final newOccupied = room.occupied - 1;
        await _firestore.collection('rooms').doc(bed.roomId).update({
          'occupied': newOccupied,
          'isAvailable': newOccupied < room.capacity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to unassign bed: $e');
    }
  }

  /// Get all students in a room (from beds)
  /// Get student's assigned bed and room details
  Future<Map<String, dynamic>?> getStudentBedDetails(String studentId) async {
    try {
      // Get bed assigned to student
      final beds = await _firestore
          .collection('beds')
          .where('studentId', isEqualTo: studentId)
          .where('isOccupied', isEqualTo: true)
          .limit(1)
          .get();

      if (beds.docs.isEmpty) {
        return null;
      }

      final bed = BedModel.fromFirestore(beds.docs.first);
      
      // Get room details
      final room = await getRoom(bed.roomId);
      if (room == null) {
        return null;
      }

      // Get floor details
      final floor = await getFloor(room.floorId);
      if (floor == null) {
        return null;
      }

      // Get hall details
      final hall = await getHall(floor.hallId);
      if (hall == null) {
        return null;
      }

      return {
        'bedId': bed.id,
        'bedNumber': bed.bedNumber,
        'roomId': room.id,
        'roomName': room.name,
        'floorId': floor.id,
        'floorName': floor.name,
        'hallId': hall.id,
        'hallName': hall.name,
      };
    } catch (e) {
      debugPrint('Error getting student bed details: $e');
      return null;
    }
  }

  /// Returns a list of maps with student info: {studentId, bedNumber, bedId}
  Future<List<Map<String, dynamic>>> getStudentsInRoom(String roomId) async {
    try {
      // Get all beds for the room and filter in memory to avoid index requirement
      final allBeds = await _firestore
          .collection('beds')
          .where('roomId', isEqualTo: roomId)
          .get();

      final students = <Map<String, dynamic>>[];
      
      // Filter occupied beds in memory
      final occupiedBeds = allBeds.docs.where((doc) {
        final data = doc.data();
        return data['isOccupied'] == true && data['studentId'] != null;
      });
      
      for (var bedDoc in occupiedBeds) {
        final bed = BedModel.fromFirestore(bedDoc);
        if (bed.studentId != null) {
          // Get student profile
          final studentDoc = await _firestore
              .collection('profiles')
              .doc(bed.studentId!)
              .get();
          
          if (studentDoc.exists) {
            final studentData = studentDoc.data()!;
            students.add({
              'studentId': bed.studentId!,
              'bedId': bed.id,
              'bedNumber': bed.bedNumber,
              'name': studentData['name'] ?? 'Unknown',
              'email': studentData['email'] ?? '',
              'phoneNumber': studentData['phoneNumber'] ?? studentData['phone'] ?? '',
              'arnRollNumber': studentData['arnRollNumber'] ?? '',
            });
          } else {
            // Student profile not found, but bed is occupied
            students.add({
              'studentId': bed.studentId!,
              'bedId': bed.id,
              'bedNumber': bed.bedNumber,
              'name': 'Unknown',
              'email': '',
              'phoneNumber': '',
              'arnRollNumber': '',
            });
          }
        }
      }
      
      // Sort by bed number
      students.sort((a, b) => (a['bedNumber'] as String).compareTo(b['bedNumber'] as String));
      
      return students;
    } catch (e) {
      throw Exception('Failed to get students in room: $e');
    }
  }

  // ==================== HOSTEL VISIBILITY MANAGEMENT ====================

  /// Set hostel visibility (which students can see which hostels)
  Future<void> setHostelVisibility({
    required String hostelId,
    List<String>? visibleToStudentIds,
    List<String>? visibleToAcademicYears,
  }) async {
    try {
      // Check if visibility record exists
      final visibilityQuery = await _firestore
          .collection('hostelVisibility')
          .where('hostelId', isEqualTo: hostelId)
          .limit(1)
          .get();

      final visibilityData = {
        'hostelId': hostelId,
        'visibleToStudentIds': visibleToStudentIds ?? [],
        'visibleToAcademicYears': visibleToAcademicYears ?? [],
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (visibilityQuery.docs.isEmpty) {
        // Create new visibility record
        final visibilityId = _uuid.v4();
        await _firestore
            .collection('hostelVisibility')
            .doc(visibilityId)
            .set({
          ...visibilityData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update existing visibility record
        await _firestore
            .collection('hostelVisibility')
            .doc(visibilityQuery.docs.first.id)
            .update(visibilityData);
      }
    } catch (e) {
      throw Exception('Failed to set hostel visibility: $e');
    }
  }

  /// Get hostel visibility
  Future<HostelVisibilityModel?> getHostelVisibility(String hostelId) async {
    try {
      final query = await _firestore
          .collection('hostelVisibility')
          .where('hostelId', isEqualTo: hostelId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return HostelVisibilityModel.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get hostel visibility: $e');
    }
  }

  /// Check if student can see a hostel
  Future<bool> canStudentSeeHostel({
    required String hostelId,
    required String studentId,
    String? academicYear,
  }) async {
    try {
      final visibility = await getHostelVisibility(hostelId);
      if (visibility == null) {
        // If no visibility set, all students can see it
        return true;
      }

      // Check if student ID is in visible list
      if (visibility.visibleToStudentIds.contains(studentId)) {
        return true;
      }

      // Check if academic year is in visible list
      if (academicYear != null &&
          visibility.visibleToAcademicYears.contains(academicYear)) {
        return true;
      }

      // If both lists are empty, all students can see it
      if (visibility.visibleToStudentIds.isEmpty &&
          visibility.visibleToAcademicYears.isEmpty) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking hostel visibility: $e');
      return false;
    }
  }

  /// Get visible hostels for a student
  Stream<List<HostelModel>> getVisibleHostelsForStudent({
    required String studentId,
    String? academicYear,
  }) {
    return _firestore.collection('hostels').snapshots().asyncMap((snapshot) async {
      final visibleHostels = <HostelModel>[];

      for (var doc in snapshot.docs) {
        final hostel = HostelModel.fromFirestore(doc);
        final canSee = await canStudentSeeHostel(
          hostelId: hostel.id,
          studentId: studentId,
          academicYear: academicYear,
        );
        if (canSee) {
          visibleHostels.add(hostel);
        }
      }

      return visibleHostels;
    });
  }

  // ==================== GET FULL HIERARCHY ====================

  /// Get complete hierarchy: Hostel -> Hall -> Floor -> Room
  Future<Map<String, dynamic>> getHostelHierarchy(String hostelId) async {
    try {
      final hostelDoc = await _firestore.collection('hostels').doc(hostelId).get();
      if (!hostelDoc.exists) {
        throw Exception('Hostel not found');
      }

      final hostel = HostelModel.fromFirestore(hostelDoc);
      // Get all halls and filter in memory to avoid index requirement
      final allHalls = await _firestore
          .collection('halls')
          .get();
      final halls = allHalls.docs.where((doc) {
        final data = doc.data();
        return data['hostelId'] == hostelId;
      });

      final hallsData = <Map<String, dynamic>>[];

      for (var hallDoc in halls) {
        final hall = HallModel.fromFirestore(hallDoc);
        final floorsSnapshot = await _firestore
            .collection('floors')
            .where('hallId', isEqualTo: hall.id)
            .get();
        final floors = floorsSnapshot.docs
            .map((doc) => FloorModel.fromFirestore(doc))
            .toList();
        // Sort in-memory by floorNumber to avoid index requirement
        floors.sort((a, b) => a.floorNumber.compareTo(b.floorNumber));

        final floorsData = <Map<String, dynamic>>[];

        for (var floor in floors) {
          final rooms = await _firestore
              .collection('rooms')
              .where('floorId', isEqualTo: floor.id)
              .get();

          final roomsData = rooms.docs.map((roomDoc) {
            final room = RoomModel.fromFirestore(roomDoc);
            return {
              'id': room.id,
              'name': room.name,
              'capacity': room.capacity,
              'occupied': room.occupied,
              'availableBeds': room.availableBeds,
              'isAvailable': room.isAvailable,
            };
          }).toList();

          floorsData.add({
            'id': floor.id,
            'name': floor.name,
            'floorNumber': floor.floorNumber,
            'rooms': roomsData,
          });
        }

        hallsData.add({
          'id': hall.id,
          'name': hall.name,
          'floors': floorsData,
        });
      }

      return {
        'hostel': {
          'id': hostel.id,
          'name': hostel.name,
          'gender': hostel.gender,
        },
        'halls': hallsData,
      };
    } catch (e) {
      throw Exception('Failed to get hostel hierarchy: $e');
    }
  }
}


