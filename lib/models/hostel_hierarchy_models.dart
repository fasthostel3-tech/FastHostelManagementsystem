import 'package:cloud_firestore/cloud_firestore.dart';

/// ==================== DATABASE SCHEMA ====================
/// 
/// Collections Structure:
/// 
/// hostels/{hostelId}
///   - name: String
///   - type: String ('boys' | 'girls')
///   - gender: String
///   - description: String?
///   - createdAt: Timestamp
///   - updatedAt: Timestamp
/// 
/// halls/{hallId}
///   - hostelId: String (FK to hostels)
///   - name: String
///   - description: String?
///   - createdAt: Timestamp
///   - updatedAt: Timestamp
/// 
/// floors/{floorId}
///   - hallId: String (FK to halls)
///   - name: String
///   - floorNumber: int
///   - description: String?
///   - createdAt: Timestamp
///   - updatedAt: Timestamp
/// 
/// rooms/{roomId}
///   - floorId: String (FK to floors)
///   - name: String
///   - capacity: int (>= 1)
///   - occupied: int (default: 0)
///   - isAvailable: bool
///   - description: String?
///   - createdAt: Timestamp
///   - updatedAt: Timestamp

/// Hostel Type Enum
enum HostelType {
  boys,
  girls;

  String get value => name;
  static HostelType fromString(String value) {
    return HostelType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => HostelType.boys,
    );
  }
}

/// ==================== HOSTEL MODEL ====================
class HostelHierarchyModel {
  final String id;
  final String name;
  final HostelType type;
  final String gender; // 'male' or 'female'
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  HostelHierarchyModel({
    required this.id,
    required this.name,
    required this.type,
    required this.gender,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HostelHierarchyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HostelHierarchyModel(
      id: doc.id,
      name: data['name'] ?? '',
      type: HostelType.fromString(data['type'] ?? 'boys'),
      gender: data['gender'] ?? 'male',
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.value,
      'gender': gender,
      if (description != null) 'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  HostelHierarchyModel copyWith({
    String? id,
    String? name,
    HostelType? type,
    String? gender,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HostelHierarchyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      gender: gender ?? this.gender,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// ==================== HALL MODEL ====================
class HallHierarchyModel {
  final String id;
  final String hostelId; // Foreign Key
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  HallHierarchyModel({
    required this.id,
    required this.hostelId,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HallHierarchyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HallHierarchyModel(
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

  HallHierarchyModel copyWith({
    String? id,
    String? hostelId,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HallHierarchyModel(
      id: id ?? this.id,
      hostelId: hostelId ?? this.hostelId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// ==================== FLOOR MODEL ====================
class FloorHierarchyModel {
  final String id;
  final String hallId; // Foreign Key
  final String name;
  final int floorNumber;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  FloorHierarchyModel({
    required this.id,
    required this.hallId,
    required this.name,
    required this.floorNumber,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FloorHierarchyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FloorHierarchyModel(
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

  FloorHierarchyModel copyWith({
    String? id,
    String? hallId,
    String? name,
    int? floorNumber,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FloorHierarchyModel(
      id: id ?? this.id,
      hallId: hallId ?? this.hallId,
      name: name ?? this.name,
      floorNumber: floorNumber ?? this.floorNumber,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// ==================== ROOM MODEL ====================
class RoomHierarchyModel {
  final String id;
  final String floorId; // Foreign Key
  final String name;
  final int capacity; // Must be >= 1
  final int occupied; // Default: 0
  final bool isAvailable;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoomHierarchyModel({
    required this.id,
    required this.floorId,
    required this.name,
    required this.capacity,
    this.occupied = 0,
    this.isAvailable = true,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RoomHierarchyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomHierarchyModel(
      id: doc.id,
      floorId: data['floorId'] ?? '',
      name: data['name'] ?? '',
      capacity: data['capacity'] ?? 1,
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

  RoomHierarchyModel copyWith({
    String? id,
    String? floorId,
    String? name,
    int? capacity,
    int? occupied,
    bool? isAvailable,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoomHierarchyModel(
      id: id ?? this.id,
      floorId: floorId ?? this.floorId,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      occupied: occupied ?? this.occupied,
      isAvailable: isAvailable ?? this.isAvailable,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Computed properties
  int get availableSpots => capacity - occupied;
  bool get hasSpace => occupied < capacity;
  double get occupancyRate => capacity > 0 ? occupied / capacity : 0.0;
}
