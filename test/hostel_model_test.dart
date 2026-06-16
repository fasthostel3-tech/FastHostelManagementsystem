import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fast_hostel_system/models/hostel_model.dart';

void main() {
  group('HostelModel Tests', () {
    late HostelModel hostel;
    final now = DateTime.now();

    setUp(() {
      hostel = HostelModel(
        id: 'H1',
        name: 'Jinnah Hall',
        gender: 'male',
        totalFloors: 3,
        description: 'A modern hostel facility',
        createdAt: now,
        updatedAt: now,
      );
    });

    test('Hostel initialization with correct values', () {
      expect(hostel.id, 'H1');
      expect(hostel.name, 'Jinnah Hall');
      expect(hostel.gender, 'male');
      expect(hostel.totalFloors, 3);
      expect(hostel.description, 'A modern hostel facility');
      expect(hostel.createdAt, now);
      expect(hostel.updatedAt, now);
    });

    test('Hostel toFirestore converts correctly', () {
      final data = hostel.toFirestore();
      
      expect(data['name'], hostel.name);
      expect(data['gender'], hostel.gender);
      expect(data['totalFloors'], hostel.totalFloors);
      expect(data['description'], hostel.description);
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
    });
  });
}