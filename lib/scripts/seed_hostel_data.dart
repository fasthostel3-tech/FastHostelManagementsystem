import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hostel_hierarchy_model.dart';
import '../services/hostel_hierarchy_service.dart';

/// Seed script to populate initial hostel data
/// Creates: 1 Boys Hostel, 1 Girls Hostel with Halls → Floors → Rooms
class HostelDataSeeder {
  final HostelHierarchyService _service;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  HostelDataSeeder(this._service);

  /// Run seed script
  Future<void> seed() async {
    print('🌱 Starting hostel data seeding...');

    try {
      // Check if data already exists
      final existingHostels = await _firestore
          .collection('hostels')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (existingHostels.docs.isNotEmpty) {
        print('⚠️  Hostels already exist. Skipping seed.');
        return;
      }

      // 1. Create Boys Hostel
      print('📦 Creating Boys Hostel...');
      final boysHostelId = await _service.createHostel(
        name: 'Boys Hostel Alpha',
        type: HostelType.boys,
        description: 'Main boys hostel with modern facilities',
        address: 'Block A, University Campus',
      );
      print('✅ Boys Hostel created: $boysHostelId');

      // Create Halls for Boys Hostel
      final boysHall1Id = await _service.createHall(
        hostelId: boysHostelId,
        name: 'North Hall',
        description: 'North wing of boys hostel',
      );
      final boysHall2Id = await _service.createHall(
        hostelId: boysHostelId,
        name: 'South Hall',
        description: 'South wing of boys hostel',
      );
      print('✅ Created 2 halls for Boys Hostel');

      // Create Floors for Boys Hall 1
      final boysHall1Floor1Id = await _service.createFloor(
        hallId: boysHall1Id,
        name: 'Ground Floor',
        floorNumber: 0,
      );
      final boysHall1Floor2Id = await _service.createFloor(
        hallId: boysHall1Id,
        name: 'First Floor',
        floorNumber: 1,
      );
      print('✅ Created 2 floors for North Hall');

      // Create Rooms for Boys Hall 1 Floor 1 (Ground Floor)
      await _service.createRoom(
        floorId: boysHall1Floor1Id,
        name: 'Room 101',
        capacity: 2,
        description: 'Double occupancy room',
      );
      await _service.createRoom(
        floorId: boysHall1Floor1Id,
        name: 'Room 102',
        capacity: 3,
        description: 'Triple occupancy room',
      );
      await _service.createRoom(
        floorId: boysHall1Floor1Id,
        name: 'Room 103',
        capacity: 4,
        description: 'Quad occupancy room',
      );
      print('✅ Created 3 rooms for Ground Floor (North Hall)');

      // Create Rooms for Boys Hall 1 Floor 2 (First Floor)
      await _service.createRoom(
        floorId: boysHall1Floor2Id,
        name: 'Room 201',
        capacity: 2,
      );
      await _service.createRoom(
        floorId: boysHall1Floor2Id,
        name: 'Room 202',
        capacity: 2,
      );
      print('✅ Created 2 rooms for First Floor (North Hall)');

      // Create Floors for Boys Hall 2
      final boysHall2Floor1Id = await _service.createFloor(
        hallId: boysHall2Id,
        name: 'Ground Floor',
        floorNumber: 0,
      );
      await _service.createRoom(
        floorId: boysHall2Floor1Id,
        name: 'Room 301',
        capacity: 1,
        description: 'Single occupancy room',
      );
      await _service.createRoom(
        floorId: boysHall2Floor1Id,
        name: 'Room 302',
        capacity: 2,
      );
      print('✅ Created rooms for South Hall');

      // 2. Create Girls Hostel
      print('📦 Creating Girls Hostel...');
      final girlsHostelId = await _service.createHostel(
        name: 'Girls Hostel Beta',
        type: HostelType.girls,
        description: 'Main girls hostel with security and amenities',
        address: 'Block B, University Campus',
      );
      print('✅ Girls Hostel created: $girlsHostelId');

      // Create Halls for Girls Hostel
      final girlsHall1Id = await _service.createHall(
        hostelId: girlsHostelId,
        name: 'East Hall',
        description: 'East wing of girls hostel',
      );
      final girlsHall2Id = await _service.createHall(
        hostelId: girlsHostelId,
        name: 'West Hall',
        description: 'West wing of girls hostel',
      );
      print('✅ Created 2 halls for Girls Hostel');

      // Create Floors for Girls Hall 1
      final girlsHall1Floor1Id = await _service.createFloor(
        hallId: girlsHall1Id,
        name: 'Ground Floor',
        floorNumber: 0,
      );
      final girlsHall1Floor2Id = await _service.createFloor(
        hallId: girlsHall1Id,
        name: 'First Floor',
        floorNumber: 1,
      );
      final girlsHall1Floor3Id = await _service.createFloor(
        hallId: girlsHall1Id,
        name: 'Second Floor',
        floorNumber: 2,
      );
      print('✅ Created 3 floors for East Hall');

      // Create Rooms for Girls Hall 1 Floor 1
      await _service.createRoom(
        floorId: girlsHall1Floor1Id,
        name: 'Room 101',
        capacity: 2,
      );
      await _service.createRoom(
        floorId: girlsHall1Floor1Id,
        name: 'Room 102',
        capacity: 2,
      );
      await _service.createRoom(
        floorId: girlsHall1Floor1Id,
        name: 'Room 103',
        capacity: 3,
      );
      print('✅ Created 3 rooms for Ground Floor (East Hall)');

      // Create Rooms for Girls Hall 1 Floor 2
      await _service.createRoom(
        floorId: girlsHall1Floor2Id,
        name: 'Room 201',
        capacity: 2,
      );
      await _service.createRoom(
        floorId: girlsHall1Floor2Id,
        name: 'Room 202',
        capacity: 4,
      );
      print('✅ Created 2 rooms for First Floor (East Hall)');

      // Create Rooms for Girls Hall 1 Floor 3
      await _service.createRoom(
        floorId: girlsHall1Floor3Id,
        name: 'Room 301',
        capacity: 1,
        description: 'Single occupancy room',
      );
      print('✅ Created 1 room for Second Floor (East Hall)');

      // Create Floors for Girls Hall 2
      final girlsHall2Floor1Id = await _service.createFloor(
        hallId: girlsHall2Id,
        name: 'Ground Floor',
        floorNumber: 0,
      );
      await _service.createRoom(
        floorId: girlsHall2Floor1Id,
        name: 'Room 401',
        capacity: 2,
      );
      await _service.createRoom(
        floorId: girlsHall2Floor1Id,
        name: 'Room 402',
        capacity: 3,
      );
      print('✅ Created rooms for West Hall');

      print('🎉 Hostel data seeding completed successfully!');
      print('\n📊 Summary:');
      print('  - 2 Hostels (1 Boys, 1 Girls)');
      print('  - 4 Halls total');
      print('  - 7 Floors total');
      print('  - 15+ Rooms with varying capacities (1-4 persons)');
    } catch (e) {
      print('❌ Error seeding data: $e');
      rethrow;
    }
  }

  /// Clear all seeded data (for testing)
  Future<void> clearSeedData() async {
    print('🗑️  Clearing seed data...');
    try {
      final hostels = await _firestore
          .collection('hostels')
          .where('isActive', isEqualTo: true)
          .get();

      for (final hostelDoc in hostels.docs) {
        final hostelId = hostelDoc.id;
        
        // Get all halls
        final halls = await _firestore
            .collection('halls')
            .where('hostelId', isEqualTo: hostelId)
            .get();

        for (final hallDoc in halls.docs) {
          final hallId = hallDoc.id;
          
          // Get all floors
          final floors = await _firestore
              .collection('floors')
              .where('hallId', isEqualTo: hallId)
              .get();

          for (final floorDoc in floors.docs) {
            final floorId = floorDoc.id;
            
            // Delete all rooms
            final rooms = await _firestore
                .collection('rooms')
                .where('floorId', isEqualTo: floorId)
                .get();

            for (final roomDoc in rooms.docs) {
              await roomDoc.reference.delete();
            }
            
            // Delete floor
            await floorDoc.reference.delete();
          }
          
          // Delete hall
          await hallDoc.reference.delete();
        }
        
        // Delete hostel
        await hostelDoc.reference.delete();
      }

      print('✅ Seed data cleared');
    } catch (e) {
      print('❌ Error clearing seed data: $e');
      rethrow;
    }
  }
}







