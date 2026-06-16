import 'package:cloud_firestore/cloud_firestore.dart';

/// Hostel Model - Top level entity
/// Supports Boys Hostel and Girls Hostel types
class HostelModel {
  final String id;
  final String name;
  final HostelType type; // Boys or Girls
  final String? description;
  final String? address;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  HostelModel({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.address,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HostelModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HostelModel(
      id: doc.id,
      name: data['name'] ?? '',
      type: HostelType.values.firstWhere(
        (e) => e.toString().split('.').last == data['type'],
        orElse: () => HostelType.boys,
      ),
      description: data['description'],
      address: data['address'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.toString().split('.').last,
      'description': description,
      'address': address,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  HostelModel copyWith({
    String? id,
    String? name,
    HostelType? type,
    String? description,
    String? address,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HostelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum HostelType { boys, girls }

/// Hall Model - Belongs to a Hostel
class HallModel {
  final String id;
  final String hostelId; // Foreign key to HostelModel
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  HallModel({
    required this.id,
    required this.hostelId,
    required this.name,
    this.description,
    this.isActive = true,
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
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hostelId': hostelId,
      'name': name,
      'description': description,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  HallModel copyWith({
    String? id,
    String? hostelId,
    String? name,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HallModel(
      id: id ?? this.id,
      hostelId: hostelId ?? this.hostelId,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Floor Model - Belongs to a Hall
class FloorModel {
  final String id;
  final String hallId; // Foreign key to HallModel
  final String name; // e.g., "Ground Floor", "First Floor"
  final int floorNumber; // Numeric floor number for ordering
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  FloorModel({
    required this.id,
    required this.hallId,
    required this.name,
    required this.floorNumber,
    this.description,
    this.isActive = true,
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
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hallId': hallId,
      'name': name,
      'floorNumber': floorNumber,
      'description': description,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  FloorModel copyWith({
    String? id,
    String? hallId,
    String? name,
    int? floorNumber,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FloorModel(
      id: id ?? this.id,
      hallId: hallId ?? this.hallId,
      name: name ?? this.name,
      floorNumber: floorNumber ?? this.floorNumber,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Room Model - Belongs to a Floor
/// Admin defines capacity (how many persons can stay)
class RoomModel {
  final String id;
  final String floorId; // Foreign key to FloorModel
  final String name; // e.g., "Room 101", "Room 201"
  final int capacity; // Number of persons (validated: >= 1)
  final int occupied; // Current number of occupied beds
  final bool isAvailable;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoomModel({
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

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomModel(
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
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  RoomModel copyWith({
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
    return RoomModel(
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

  /// Check if room has available space
  bool get hasSpace => occupied < capacity;

  /// Get available beds count
  int get availableBeds => capacity - occupied;
}







