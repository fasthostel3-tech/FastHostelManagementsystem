import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for Hall (within a Hostel)
class HallModel {
  final String id;
  final String hostelId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  HallModel({
    required this.id,
    required this.hostelId,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HallModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HallModel(
      id: doc.id,
      hostelId: data['hostelId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hostelId': hostelId,
      'name': name,
      if (description != null) 'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

/// Model for Floor (within a Hall)
class FloorModel {
  final String id;
  final String hallId;
  final String name;
  final int floorNumber;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  FloorModel({
    required this.id,
    required this.hallId,
    required this.name,
    required this.floorNumber,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FloorModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FloorModel(
      id: doc.id,
      hallId: data['hallId'] ?? '',
      name: data['name'] ?? '',
      floorNumber: data['floorNumber'] ?? 0,
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hallId': hallId,
      'name': name,
      'floorNumber': floorNumber,
      if (description != null) 'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

/// Model for Room (within a Floor)
class RoomModel {
  final String id;
  final String floorId;
  final String name; // Room name/number
  final int capacity; // Total beds in room
  final int occupied; // Number of occupied beds
  final bool isAvailable;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoomModel({
    required this.id,
    required this.floorId,
    required this.name,
    required this.capacity,
    required this.occupied,
    required this.isAvailable,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomModel(
      id: doc.id,
      floorId: data['floorId'] ?? '',
      name: data['name'] ?? '',
      capacity: data['capacity'] ?? 0,
      occupied: data['occupied'] ?? 0,
      isAvailable: data['isAvailable'] ?? true,
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'floorId': floorId,
      'name': name,
      'capacity': capacity,
      'occupied': occupied,
      'isAvailable': isAvailable,
      if (description != null) 'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  int get availableBeds => capacity - occupied;
  bool get hasSpace => occupied < capacity;
}

/// Model for Bed (within a Room)
class BedModel {
  final String id;
  final String roomId;
  final String bedNumber; // e.g., "Bed 1", "Bed A"
  final String? studentId; // Occupied by student
  final bool isOccupied;
  final DateTime createdAt;
  final DateTime updatedAt;

  BedModel({
    required this.id,
    required this.roomId,
    required this.bedNumber,
    this.studentId,
    required this.isOccupied,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BedModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BedModel(
      id: doc.id,
      roomId: data['roomId'] ?? '',
      bedNumber: data['bedNumber'] ?? '',
      studentId: data['studentId'],
      isOccupied: data['isOccupied'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'roomId': roomId,
      'bedNumber': bedNumber,
      if (studentId != null) 'studentId': studentId,
      'isOccupied': isOccupied,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

/// Model for Hostel Visibility (which students can see which hostels)
class HostelVisibilityModel {
  final String id;
  final String hostelId;
  final List<String> visibleToStudentIds; // List of student UIDs who can see this hostel
  final List<String> visibleToAcademicYears; // e.g., ['Freshman', 'Sophomore']
  final DateTime createdAt;
  final DateTime updatedAt;

  HostelVisibilityModel({
    required this.id,
    required this.hostelId,
    required this.visibleToStudentIds,
    required this.visibleToAcademicYears,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HostelVisibilityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HostelVisibilityModel(
      id: doc.id,
      hostelId: data['hostelId'] ?? '',
      visibleToStudentIds: List<String>.from(data['visibleToStudentIds'] ?? []),
      visibleToAcademicYears: List<String>.from(data['visibleToAcademicYears'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hostelId': hostelId,
      'visibleToStudentIds': visibleToStudentIds,
      'visibleToAcademicYears': visibleToAcademicYears,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}









