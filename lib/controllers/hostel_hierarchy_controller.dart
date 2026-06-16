import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hostel_hierarchy_model.dart';
import '../services/hostel_hierarchy_service.dart';

/// Controller for Hostel Hierarchy operations
/// Acts as a bridge between UI and Service layer
/// Handles business logic and error formatting
class HostelHierarchyController {
  final HostelHierarchyService _service;

  HostelHierarchyController(this._service);

  // ==================== HOSTEL OPERATIONS ====================

  /// Create hostel (with validation)
  Future<Map<String, dynamic>> createHostel({
    required String name,
    required HostelType type,
    String? description,
    String? address,
  }) async {
    try {
      final hostelId = await _service.createHostel(
        name: name,
        type: type,
        description: description,
        address: address,
      );

      return {
        'success': true,
        'message': 'Hostel created successfully',
        'data': {'hostelId': hostelId},
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': null,
      };
    }
  }

  /// Get all hostels
  Stream<List<HostelModel>> getAllHostels() {
    return _service.getAllHostels();
  }

  /// Get hostels by type
  Stream<List<HostelModel>> getHostelsByType(HostelType type) {
    return _service.getHostelsByType(type);
  }

  /// Update hostel
  Future<Map<String, dynamic>> updateHostel({
    required String hostelId,
    String? name,
    HostelType? type,
    String? description,
    String? address,
    bool? isActive,
  }) async {
    try {
      await _service.updateHostel(
        hostelId: hostelId,
        name: name,
        type: type,
        description: description,
        address: address,
        isActive: isActive,
      );

      return {
        'success': true,
        'message': 'Hostel updated successfully',
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': null,
      };
    }
  }

  /// Delete hostel
  Future<Map<String, dynamic>> deleteHostel(String hostelId) async {
    try {
      await _service.deleteHostel(hostelId);

      return {
        'success': true,
        'message': 'Hostel deleted successfully',
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': null,
      };
    }
  }

  // ==================== HALL OPERATIONS ====================

  /// Create hall
  Future<Map<String, dynamic>> createHall({
    required String hostelId,
    required String name,
    String? description,
  }) async {
    try {
      final hallId = await _service.createHall(
        hostelId: hostelId,
        name: name,
        description: description,
      );

      return {
        'success': true,
        'message': 'Hall created successfully',
        'data': {'hallId': hallId},
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': null,
      };
    }
  }

  /// Get halls for hostel
  Stream<List<HallModel>> getHallsForHostel(String hostelId) {
    return _service.getHallsForHostel(hostelId);
  }

  /// Update hall
  Future<Map<String, dynamic>> updateHall({
    required String hallId,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    try {
      await _service.updateHall(
        hallId: hallId,
        name: name,
        description: description,
        isActive: isActive,
      );

      return {
        'success': true,
        'message': 'Hall updated successfully',
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': null,
      };
    }
  }

  /// Delete hall
  Future<Map<String, dynamic>> deleteHall(String hallId) async {
    try {
      await _service.deleteHall(hallId);

      return {
        'success': true,
        'message': 'Hall deleted successfully',
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': null,
      };
    }
  }

  // ==================== FLOOR OPERATIONS ====================

  /// Create floor
  Future<Map<String, dynamic>> createFloor({
    required String hallId,
    required String name,
    required int floorNumber,
    String? description,
  }) async {
    try {
      final floorId = await _service.createFloor(
        hallId: hallId,
        name: name,
        floorNumber: floorNumber,
        description: description,
      );

      return {
        'success': true,
        'message': 'Floor created successfully',
        'data': {'floorId': floorId},
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': null,
      };
    }
  }

  /// Get floors for hall
  Stream<List<FloorModel>> getFloorsForHall(String hallId) {
    return _service.getFloorsForHall(hallId);
  }

  /// Update floor
  Future<Map<String, dynamic>> updateFloor({
    required String floorId,
    String? name,
    int? floorNumber,
    String? description,
    bool? isActive,
  }) async {
    try {
      await _service.updateFloor(
        floorId: floorId,
        name: name,
        floorNumber: floorNumber,
        description: description,
        isActive: isActive,
      );

      return {
        'success': true,
        'message': 'Floor updated successfully',
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': null,
      };
    }
  }

  /// Delete floor
  Future<Map<String, dynamic>> deleteFloor(String floorId) async {
    try {
      await _service.deleteFloor(floorId);

      return {
        'success': true,
        'message': 'Floor deleted successfully',
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': null,
      };
    }
  }

  // ==================== ROOM OPERATIONS ====================

  /// Create room (with capacity validation)
  Future<Map<String, dynamic>> createRoom({
    required String floorId,
    required String name,
    required int capacity,
    String? description,
  }) async {
    try {
      // Additional validation
      if (capacity < 1) {
        return {
          'success': false,
          'message': 'Room capacity must be >= 1',
          'data': null,
        };
      }

      final roomId = await _service.createRoom(
        floorId: floorId,
        name: name,
        capacity: capacity,
        description: description,
      );

      return {
        'success': true,
        'message': 'Room created successfully',
        'data': {'roomId': roomId},
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': null,
      };
    }
  }

  /// Get rooms for floor
  Stream<List<RoomModel>> getRoomsForFloor(String floorId) {
    return _service.getRoomsForFloor(floorId);
  }

  /// Update room
  Future<Map<String, dynamic>> updateRoom({
    required String roomId,
    String? name,
    int? capacity,
    String? description,
    bool? isAvailable,
  }) async {
    try {
      if (capacity != null && capacity < 1) {
        return {
          'success': false,
          'message': 'Room capacity must be >= 1',
          'data': null,
        };
      }

      await _service.updateRoom(
        roomId: roomId,
        name: name,
        capacity: capacity,
        description: description,
        isAvailable: isAvailable,
      );

      return {
        'success': true,
        'message': 'Room updated successfully',
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': null,
      };
    }
  }

  /// Delete room
  Future<Map<String, dynamic>> deleteRoom(String roomId) async {
    try {
      await _service.deleteRoom(roomId);

      return {
        'success': true,
        'message': 'Room deleted successfully',
        'data': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': null,
      };
    }
  }

  /// Get complete hierarchy
  Future<Map<String, dynamic>> getHostelHierarchy(String hostelId) async {
    try {
      final hierarchy = await _service.getHostelHierarchy(hostelId);

      return {
        'success': true,
        'message': 'Hierarchy retrieved successfully',
        'data': hierarchy,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceFirst('Exception: ', ''),
        'data': null,
      };
    }
  }
}

/// Provider for HostelHierarchyController
final hostelHierarchyControllerProvider = Provider<HostelHierarchyController>((ref) {
  final service = ref.watch(hostelHierarchyServiceProvider);
  return HostelHierarchyController(service);
});







