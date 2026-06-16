import 'package:flutter_test/flutter_test.dart';
import 'package:fast_hostel_system/models/room_model.dart';

void main() {
  group('RoomModel Tests', () {
    late RoomModel room;

    setUp(() {
      room = RoomModel(
        id: 'R101',
        number: '101',
        type: RoomType.double,
        status: RoomStatus.available,
        floor: 1,
        capacity: 2,
        occupiedCount: 0,
        price: 67000.0,
        occupants: [],
      );
    });

    test('Room initialization with correct values', () {
      expect(room.id, 'R101');
      expect(room.number, '101');
      expect(room.type, RoomType.double);
      expect(room.status, RoomStatus.available);
      expect(room.floor, 1);
      expect(room.capacity, 2);
      expect(room.occupiedCount, 0);
      expect(room.price, 67000.0);
      expect(room.occupants, isEmpty);
    });

    test('Room can be created with facilities', () {
      final roomWithFacilities = RoomModel(
        id: 'R102',
        number: '102',
        type: RoomType.single,
        status: RoomStatus.available,
        floor: 1,
        capacity: 1,
        occupiedCount: 0,
        price: 70000.0,
        occupants: [],
        facilities: ['AC', 'Attached Bathroom'],
      );

      expect(roomWithFacilities.facilities, isNotNull);
      expect(roomWithFacilities.facilities!.length, 2);
      expect(roomWithFacilities.facilities!.contains('AC'), true);
    });

    test('Room occupancy tracking', () {
      expect(room.occupiedCount, 0);
      expect(room.capacity, 2);
      expect(room.occupants.isEmpty, true);
    });

    test('Room status values', () {
      expect(RoomStatus.values, contains(RoomStatus.available));
      expect(RoomStatus.values, contains(RoomStatus.occupied));
      expect(RoomStatus.values, contains(RoomStatus.maintenance));
      expect(RoomStatus.values, contains(RoomStatus.reserved));
    });
  });
}