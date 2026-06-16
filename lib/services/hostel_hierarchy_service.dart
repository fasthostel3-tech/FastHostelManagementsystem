import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/hostel_hierarchy_model.dart';

/// Provider for HostelHierarchyService
final hostelHierarchyServiceProvider = Provider<HostelHierarchyService>((ref) {
  return HostelHierarchyService();
});

/// Service for managing Hostel → Hall → Floor → Room hierarchy
/// Follows clean architecture with single responsibility
class HostelHierarchyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // ==================== HOSTEL CRUD ====================

  /// Create a new hostel
  /// POST /hostels equivalent
  Future<String> createHostel({
    required String name,
    required HostelType type,
    String? description,
    String? address,
  }) async {
    try {
      // Validation
      if (name.trim().isEmpty) {
        throw Exception('Hostel name is required');
      }

      final hostelId = _uuid.v4();
      final now = DateTime.now();

      final hostel = HostelModel(
        id: hostelId,
        name: name.trim(),
        type: type,
        description: description?.trim(),
        address: address?.trim(),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection('hostels')
          .doc(hostelId)
          .set(hostel.toFirestore());

      return hostelId;
    } catch (e) {
      throw Exception('Failed to create hostel: $e');
    }
  }

  /// Get hostel by ID
  Future<HostelModel?> getHostel(String hostelId) async {
    try {
      final doc = await _firestore.collection('hostels').doc(hostelId).get();
      if (!doc.exists) return null;
      return HostelModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get hostel: $e');
    }
  }

  /// Get all hostels (no orderBy to avoid index requirement)
  Stream<List<HostelModel>> getAllHostels() {
    return _firestore
        .collection('hostels')
        .snapshots()
        .map((snapshot) {
      final hostels = snapshot.docs
          .map((doc) => HostelModel.fromFirestore(doc))
          .where((h) => h.isActive) // Filter in memory to avoid index requirement
          .toList();
      // Sort in-memory to avoid index requirement
      hostels.sort((a, b) => a.name.compareTo(b.name));
      return hostels;
    });
  }

  /// Get hostels by type
  /// No where clause to avoid index requirement - filter in memory instead
  Stream<List<HostelModel>> getHostelsByType(HostelType type) {
    final typeString = type.toString().split('.').last;
    return _firestore
        .collection('hostels')
        .snapshots()
        .map((snapshot) {
      final hostels = snapshot.docs
          .map((doc) => HostelModel.fromFirestore(doc))
          .where((h) => h.isActive && h.type.toString().split('.').last == typeString) // Filter in memory to avoid index requirement
          .toList();
      // Sort in-memory
      hostels.sort((a, b) => a.name.compareTo(b.name));
      return hostels;
    });
  }

  /// Update hostel
  Future<void> updateHostel({
    required String hostelId,
    String? name,
    HostelType? type,
    String? description,
    String? address,
    bool? isActive,
  }) async {
    try {
      final hostel = await getHostel(hostelId);
      if (hostel == null) {
        throw Exception('Hostel not found');
      }

      final updated = hostel.copyWith(
        name: name,
        type: type,
        description: description,
        address: address,
        isActive: isActive,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('hostels')
          .doc(hostelId)
          .update(updated.toFirestore());
    } catch (e) {
      throw Exception('Failed to update hostel: $e');
    }
  }

  /// Delete hostel (soft delete by setting isActive = false)
  Future<void> deleteHostel(String hostelId) async {
    try {
      // Check if hostel has halls (filter isActive in memory to avoid index requirement)
      final hallsSnapshot = await _firestore
          .collection('halls')
          .where('hostelId', isEqualTo: hostelId)
          .get();
      
      final activeHalls = hallsSnapshot.docs
          .map((doc) => HallModel.fromFirestore(doc))
          .where((h) => h.isActive)
          .take(1)
          .toList();

      if (activeHalls.isNotEmpty) {
        throw Exception('Cannot delete hostel with active halls. Delete halls first.');
      }

      await updateHostel(hostelId: hostelId, isActive: false);
    } catch (e) {
      throw Exception('Failed to delete hostel: $e');
    }
  }

  // ==================== HALL CRUD ====================

  /// Create a new hall in a hostel
  /// POST /hostels/:id/halls equivalent
  Future<String> createHall({
    required String hostelId,
    required String name,
    String? description,
  }) async {
    try {
      // Validate parent hostel exists
      final hostel = await getHostel(hostelId);
      if (hostel == null) {
        throw Exception('Hostel not found. Cannot create hall without valid hostel.');
      }

      // Validation
      if (name.trim().isEmpty) {
        throw Exception('Hall name is required');
      }

      final hallId = _uuid.v4();
      final now = DateTime.now();

      final hall = HallModel(
        id: hallId,
        hostelId: hostelId,
        name: name.trim(),
        description: description?.trim(),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore.collection('halls').doc(hallId).set(hall.toFirestore());

      return hallId;
    } catch (e) {
      throw Exception('Failed to create hall: $e');
    }
  }

  /// Get hall by ID
  Future<HallModel?> getHall(String hallId) async {
    try {
      final doc = await _firestore.collection('halls').doc(hallId).get();
      if (!doc.exists) return null;
      return HallModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get hall: $e');
    }
  }

  /// Get all halls for a hostel
  /// No orderBy to avoid index requirement
  Stream<List<HallModel>> getHallsForHostel(String hostelId) {
    return _firestore
        .collection('halls')
        .where('hostelId', isEqualTo: hostelId)
        .snapshots()
        .map((snapshot) {
      final halls = snapshot.docs
          .map((doc) => HallModel.fromFirestore(doc))
          .where((h) => h.isActive) // Filter in memory to avoid index requirement
          .toList();
      // Sort in-memory
      halls.sort((a, b) => a.name.compareTo(b.name));
      return halls;
    });
  }

  /// Update hall
  Future<void> updateHall({
    required String hallId,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    try {
      final hall = await getHall(hallId);
      if (hall == null) {
        throw Exception('Hall not found');
      }

      final updated = hall.copyWith(
        name: name,
        description: description,
        isActive: isActive,
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('halls').doc(hallId).update(updated.toFirestore());
    } catch (e) {
      throw Exception('Failed to update hall: $e');
    }
  }

  /// Delete hall (soft delete)
  Future<void> deleteHall(String hallId) async {
    try {
      // Check if hall has floors (filter isActive in memory to avoid index requirement)
      final floorsSnapshot = await _firestore
          .collection('floors')
          .where('hallId', isEqualTo: hallId)
          .get();
      final activeFloors = floorsSnapshot.docs
          .map((doc) => FloorModel.fromFirestore(doc))
          .where((f) => f.isActive)
          .take(1)
          .toList();

      if (activeFloors.isNotEmpty) {
        throw Exception('Cannot delete hall with active floors. Delete floors first.');
      }

      await updateHall(hallId: hallId, isActive: false);
    } catch (e) {
      throw Exception('Failed to delete hall: $e');
    }
  }

  // ==================== FLOOR CRUD ====================

  /// Create a new floor in a hall
  /// POST /halls/:id/floors equivalent
  Future<String> createFloor({
    required String hallId,
    required String name,
    required int floorNumber,
    String? description,
  }) async {
    try {
      // Validate parent hall exists
      final hall = await getHall(hallId);
      if (hall == null) {
        throw Exception('Hall not found. Cannot create floor without valid hall.');
      }

      // Validation
      if (name.trim().isEmpty) {
        throw Exception('Floor name is required');
      }

      if (floorNumber < 0) {
        throw Exception('Floor number must be >= 0');
      }

      final floorId = _uuid.v4();
      final now = DateTime.now();

      final floor = FloorModel(
        id: floorId,
        hallId: hallId,
        name: name.trim(),
        floorNumber: floorNumber,
        description: description?.trim(),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore.collection('floors').doc(floorId).set(floor.toFirestore());

      return floorId;
    } catch (e) {
      throw Exception('Failed to create floor: $e');
    }
  }

  /// Get floor by ID
  Future<FloorModel?> getFloor(String floorId) async {
    try {
      final doc = await _firestore.collection('floors').doc(floorId).get();
      if (!doc.exists) return null;
      return FloorModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get floor: $e');
    }
  }

  /// Get all floors for a hall
  /// No orderBy to avoid index requirement
  Stream<List<FloorModel>> getFloorsForHall(String hallId) {
    return _firestore
        .collection('floors')
        .where('hallId', isEqualTo: hallId)
        .snapshots()
        .map((snapshot) {
      final floors = snapshot.docs
          .map((doc) => FloorModel.fromFirestore(doc))
          .where((f) => f.isActive) // Filter in memory to avoid index requirement
          .toList();
      // Sort in-memory by floorNumber
      floors.sort((a, b) => a.floorNumber.compareTo(b.floorNumber));
      return floors;
    });
  }

  /// Update floor
  Future<void> updateFloor({
    required String floorId,
    String? name,
    int? floorNumber,
    String? description,
    bool? isActive,
  }) async {
    try {
      final floor = await getFloor(floorId);
      if (floor == null) {
        throw Exception('Floor not found');
      }

      if (floorNumber != null && floorNumber < 0) {
        throw Exception('Floor number must be >= 0');
      }

      final updated = floor.copyWith(
        name: name,
        floorNumber: floorNumber,
        description: description,
        isActive: isActive,
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('floors').doc(floorId).update(updated.toFirestore());
    } catch (e) {
      throw Exception('Failed to update floor: $e');
    }
  }

  /// Delete floor (soft delete)
  Future<void> deleteFloor(String floorId) async {
    try {
      // Check if floor has active rooms (filter isAvailable in memory to avoid index requirement)
      final roomsSnapshot = await _firestore
          .collection('rooms')
          .where('floorId', isEqualTo: floorId)
          .get();
      
      final activeRooms = roomsSnapshot.docs
          .map((doc) => RoomModel.fromFirestore(doc))
          .where((r) => r.isAvailable)
          .take(1)
          .toList();

      if (activeRooms.isNotEmpty) {
        throw Exception('Cannot delete floor with active rooms. Delete rooms first.');
      }

      await updateFloor(floorId: floorId, isActive: false);
    } catch (e) {
      throw Exception('Failed to delete floor: $e');
    }
  }

  // ==================== ROOM CRUD ====================

  /// Create a new room in a floor
  /// POST /floors/:id/rooms equivalent
  Future<String> createRoom({
    required String floorId,
    required String name,
    required int capacity,
    String? description,
  }) async {
    try {
      // Validate parent floor exists
      final floor = await getFloor(floorId);
      if (floor == null) {
        throw Exception('Floor not found. Cannot create room without valid floor.');
      }

      // Validation
      if (name.trim().isEmpty) {
        throw Exception('Room name is required');
      }

      // Capacity validation: must be numeric and >= 1
      if (!_isValidCapacity(capacity)) {
        throw Exception('Room capacity must be a number >= 1');
      }

      final roomId = _uuid.v4();
      final now = DateTime.now();

      final room = RoomModel(
        id: roomId,
        floorId: floorId,
        name: name.trim(),
        capacity: capacity,
        occupied: 0,
        isAvailable: true,
        description: description?.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await _firestore.collection('rooms').doc(roomId).set(room.toFirestore());

      return roomId;
    } catch (e) {
      throw Exception('Failed to create room: $e');
    }
  }

  /// Get room by ID
  Future<RoomModel?> getRoom(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (!doc.exists) return null;
      return RoomModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get room: $e');
    }
  }

  /// Get all rooms for a floor
  /// No orderBy to avoid index requirement
  Stream<List<RoomModel>> getRoomsForFloor(String floorId) {
    return _firestore
        .collection('rooms')
        .where('floorId', isEqualTo: floorId)
        .snapshots()
        .map((snapshot) {
      final rooms = snapshot.docs
          .map((doc) => RoomModel.fromFirestore(doc))
          .toList();
      // Sort in-memory by name
      rooms.sort((a, b) => a.name.compareTo(b.name));
      return rooms;
    });
  }

  /// Update room
  Future<void> updateRoom({
    required String roomId,
    String? name,
    int? capacity,
    String? description,
    bool? isAvailable,
  }) async {
    try {
      final room = await getRoom(roomId);
      if (room == null) {
        throw Exception('Room not found');
      }

      // Capacity validation
      if (capacity != null && !_isValidCapacity(capacity)) {
        throw Exception('Room capacity must be a number >= 1');
      }

      // Validate occupied doesn't exceed new capacity
      if (capacity != null && room.occupied > capacity) {
        throw Exception('Cannot set capacity less than current occupied beds (${room.occupied})');
      }

      final updated = room.copyWith(
        name: name,
        capacity: capacity,
        description: description,
        isAvailable: isAvailable,
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('rooms').doc(roomId).update(updated.toFirestore());
    } catch (e) {
      throw Exception('Failed to update room: $e');
    }
  }

  /// Delete room (soft delete by setting isAvailable = false)
  Future<void> deleteRoom(String roomId) async {
    try {
      final room = await getRoom(roomId);
      if (room == null) {
        throw Exception('Room not found');
      }

      if (room.occupied > 0) {
        throw Exception('Cannot delete room with occupied beds. Clear occupants first.');
      }

      await updateRoom(roomId: roomId, isAvailable: false);
    } catch (e) {
      throw Exception('Failed to delete room: $e');
    }
  }

  // ==================== VALIDATION HELPERS ====================

  /// Validate room capacity
  /// Capacity must be numeric and >= 1
  bool _isValidCapacity(int capacity) {
    return capacity >= 1;
  }

  // ==================== HIERARCHY QUERIES ====================

  /// Get complete hierarchy: Hostel → Hall → Floor → Room
  Future<Map<String, dynamic>> getHostelHierarchy(String hostelId) async {
    try {
      final hostel = await getHostel(hostelId);
      if (hostel == null) {
        throw Exception('Hostel not found');
      }

      final hallsSnapshot = await _firestore
          .collection('halls')
          .where('hostelId', isEqualTo: hostelId)
          .get();

      final halls = <Map<String, dynamic>>[];

      for (final hallDoc in hallsSnapshot.docs) {
        final hall = HallModel.fromFirestore(hallDoc);
        // Filter isActive in memory to avoid index requirement
        if (!hall.isActive) continue;
        
        final floorsSnapshot = await _firestore
            .collection('floors')
            .where('hallId', isEqualTo: hall.id)
            .get();

        final floors = <Map<String, dynamic>>[];

        for (final floorDoc in floorsSnapshot.docs) {
          final floor = FloorModel.fromFirestore(floorDoc);
          // Filter isActive in memory to avoid index requirement
          if (!floor.isActive) continue;
          
          final roomsSnapshot = await _firestore
              .collection('rooms')
              .where('floorId', isEqualTo: floor.id)
              .get();

          final rooms = roomsSnapshot.docs
              .map((doc) => RoomModel.fromFirestore(doc).toFirestore())
              .toList();

          floors.add({
            'floor': floor.toFirestore(),
            'rooms': rooms,
          });
        }

        halls.add({
          'hall': hall.toFirestore(),
          'floors': floors,
        });
      }

      return {
        'hostel': hostel.toFirestore(),
        'halls': halls,
      };
    } catch (e) {
      throw Exception('Failed to get hostel hierarchy: $e');
    }
  }
}
