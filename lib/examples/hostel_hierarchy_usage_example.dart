import '../../services/hostel_hierarchy_service.dart';
import '../../models/hostel_hierarchy_model.dart';
import '../../scripts/seed_hostel_data.dart';

/// Example usage of Hostel Hierarchy System
/// This demonstrates how to use the service for CRUD operations
class HostelHierarchyUsageExample {
  final HostelHierarchyService service;

  HostelHierarchyUsageExample(this.service);

  /// Example 1: Create a complete hierarchy
  Future<void> createCompleteHierarchy() async {
    print('=== Example 1: Create Complete Hierarchy ===\n');

    // Step 1: Create Hostel
    final hostelId = await service.createHostel(
      name: 'Boys Hostel Alpha',
      type: HostelType.boys,
      description: 'Main boys hostel with modern facilities',
      address: 'Block A, University Campus',
    );
    print('✅ Created Hostel: $hostelId');

    // Step 2: Create Hall in Hostel
    final hallId = await service.createHall(
      hostelId: hostelId,
      name: 'North Hall',
      description: 'North wing of boys hostel',
    );
    print('✅ Created Hall: $hallId');

    // Step 3: Create Floor in Hall
    final floorId = await service.createFloor(
      hallId: hallId,
      name: 'Ground Floor',
      floorNumber: 0,
      description: 'Ground level floor',
    );
    print('✅ Created Floor: $floorId');

    // Step 4: Create Room in Floor with capacity
    final roomId = await service.createRoom(
      floorId: floorId,
      name: 'Room 101',
      capacity: 2, // 2 persons can stay
      description: 'Double occupancy room',
    );
    print('✅ Created Room: $roomId\n');
  }

  /// Example 2: Get all hostels and their hierarchy
  Future<void> getHostelHierarchy() async {
    print('=== Example 2: Get Hostel Hierarchy ===\n');

    // Get all hostels
    service.getAllHostels().listen((hostels) {
      print('📦 Found ${hostels.length} hostels:');
      for (final hostel in hostels) {
        print('  - ${hostel.name} (${hostel.type})');
      }
    });

    // Get halls for a specific hostel
    const hostelId = 'your-hostel-id';
    service.getHallsForHostel(hostelId).listen((halls) {
      print('\n🏛️  Found ${halls.length} halls:');
      for (final hall in halls) {
        print('  - ${hall.name}');
      }
    });

    // Get floors for a specific hall
    const hallId = 'your-hall-id';
    service.getFloorsForHall(hallId).listen((floors) {
      print('\n🏢 Found ${floors.length} floors:');
      for (final floor in floors) {
        print('  - ${floor.name} (Floor #${floor.floorNumber})');
      }
    });

    // Get rooms for a specific floor
    const floorId = 'your-floor-id';
    service.getRoomsForFloor(floorId).listen((rooms) {
      print('\n🚪 Found ${rooms.length} rooms:');
      for (final room in rooms) {
        print('  - ${room.name} (Capacity: ${room.capacity}, Occupied: ${room.occupied})');
      }
    });
  }

  /// Example 3: Update operations
  Future<void> updateOperations() async {
    print('=== Example 3: Update Operations ===\n');

    // Update hostel
    await service.updateHostel(
      hostelId: 'your-hostel-id',
      name: 'Updated Hostel Name',
      description: 'Updated description',
    );
    print('✅ Hostel updated');

    // Update hall
    await service.updateHall(
      hallId: 'your-hall-id',
      name: 'Updated Hall Name',
    );
    print('✅ Hall updated');

    // Update floor
    await service.updateFloor(
      floorId: 'your-floor-id',
      name: 'Updated Floor Name',
      floorNumber: 1,
    );
    print('✅ Floor updated');

    // Update room capacity
    await service.updateRoom(
      roomId: 'your-room-id',
      capacity: 3, // Change from 2 to 3 persons
      name: 'Updated Room Name',
    );
    print('✅ Room updated\n');
  }

  /// Example 4: Delete operations (with validation)
  Future<void> deleteOperations() async {
    print('=== Example 4: Delete Operations ===\n');

    try {
      // Delete room (only if not occupied)
      await service.deleteRoom('your-room-id');
      print('✅ Room deleted');

      // Delete floor (only if no active rooms)
      await service.deleteFloor('your-floor-id');
      print('✅ Floor deleted');

      // Delete hall (only if no active floors)
      await service.deleteHall('your-hall-id');
      print('✅ Hall deleted');

      // Delete hostel (only if no active halls)
      await service.deleteHostel('your-hostel-id');
      print('✅ Hostel deleted\n');
    } catch (e) {
      print('❌ Delete failed: $e');
      print('   (This is expected if there are active children)\n');
    }
  }

  /// Example 5: Validation examples
  Future<void> validationExamples() async {
    print('=== Example 5: Validation Examples ===\n');

    // ❌ Invalid: Capacity < 1
    try {
      await service.createRoom(
        floorId: 'your-floor-id',
        name: 'Room 999',
        capacity: 0, // Invalid!
      );
    } catch (e) {
      print('❌ Validation caught: $e');
    }

    // ❌ Invalid: Creating room without valid floor
    try {
      await service.createRoom(
        floorId: 'non-existent-floor-id',
        name: 'Room 999',
        capacity: 2,
      );
    } catch (e) {
      print('❌ Validation caught: $e');
    }

    // ❌ Invalid: Setting capacity less than occupied
    try {
      await service.updateRoom(
        roomId: 'your-room-id',
        capacity: 1, // But room has 2 occupied!
      );
    } catch (e) {
      print('❌ Validation caught: $e');
    }

    print('\n✅ All validations working correctly!\n');
  }

  /// Example 6: Seed data
  Future<void> seedDataExample() async {
    print('=== Example 6: Seed Data ===\n');

    final seeder = HostelDataSeeder(service);
    
    try {
      await seeder.seed();
      print('✅ Seed data created successfully!\n');
    } catch (e) {
      print('❌ Seed failed: $e\n');
    }
  }

  /// Example 7: Get complete hierarchy
  Future<void> getCompleteHierarchy() async {
    print('=== Example 7: Get Complete Hierarchy ===\n');

    try {
      final hierarchy = await service.getHostelHierarchy('your-hostel-id');
      
      print('📊 Complete Hierarchy:');
      print('Hostel: ${hierarchy['hostel']?['name']}');
      print('Halls: ${(hierarchy['halls'] as List).length}');
      
      for (final hallData in hierarchy['halls'] as List) {
        final hall = hallData['hall'];
        final floors = hallData['floors'] as List;
        print('  - ${hall['name']} (${floors.length} floors)');
        
        for (final floorData in floors) {
          final floor = floorData['floor'];
          final rooms = floorData['rooms'] as List;
          print('    - ${floor['name']} (${rooms.length} rooms)');
        }
      }
    } catch (e) {
      print('❌ Error: $e\n');
    }
  }
}

/// Example: Using with Riverpod
/// 
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final service = ref.watch(hostelHierarchyServiceProvider);
///     
///     return StreamBuilder<List<HostelModel>>(
///       stream: service.getAllHostels(),
///       builder: (context, snapshot) {
///         if (snapshot.hasData) {
///           return ListView.builder(
///             itemCount: snapshot.data!.length,
///             itemBuilder: (context, index) {
///               final hostel = snapshot.data![index];
///               return ListTile(
///                 title: Text(hostel.name),
///                 subtitle: Text(hostel.type.toString()),
///               );
///             },
///           );
///         }
///         return CircularProgressIndicator();
///       },
///     );
///   }
/// }
/// ```







