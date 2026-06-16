/// ==================== DATA TRANSFER OBJECTS (DTOs) ====================
/// 
/// DTOs are used for API requests/responses and validation
/// They separate the data layer from the business logic layer
library;

/// Create Hostel DTO
class CreateHostelDto {
  final String name;
  final String type; // 'boys' or 'girls'
  final String? description;

  CreateHostelDto({
    required this.name,
    required this.type,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        if (description != null) 'description': description,
      };

  factory CreateHostelDto.fromJson(Map<String, dynamic> json) => CreateHostelDto(
        name: json['name'] as String,
        type: json['type'] as String,
        description: json['description'] as String?,
      );

  void validate() {
    if (name.trim().isEmpty) {
      throw Exception('Hostel name is required');
    }
    if (type != 'boys' && type != 'girls') {
      throw Exception('Hostel type must be "boys" or "girls"');
    }
  }
}

/// Update Hostel DTO
class UpdateHostelDto {
  final String? name;
  final String? type;
  final String? description;

  UpdateHostelDto({
    this.name,
    this.type,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (type != null) 'type': type,
        if (description != null) 'description': description,
      };

  void validate() {
    if (type != null && type != 'boys' && type != 'girls') {
      throw Exception('Hostel type must be "boys" or "girls"');
    }
  }
}

/// Create Hall DTO
class CreateHallDto {
  final String hostelId;
  final String name;
  final String? description;

  CreateHallDto({
    required this.hostelId,
    required this.name,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'hostelId': hostelId,
        'name': name,
        if (description != null) 'description': description,
      };

  factory CreateHallDto.fromJson(Map<String, dynamic> json) => CreateHallDto(
        hostelId: json['hostelId'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
      );

  void validate() {
    if (hostelId.trim().isEmpty) {
      throw Exception('Hostel ID is required');
    }
    if (name.trim().isEmpty) {
      throw Exception('Hall name is required');
    }
  }
}

/// Update Hall DTO
class UpdateHallDto {
  final String? name;
  final String? description;

  UpdateHallDto({
    this.name,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      };
}

/// Create Floor DTO
class CreateFloorDto {
  final String hallId;
  final String name;
  final int floorNumber;
  final String? description;

  CreateFloorDto({
    required this.hallId,
    required this.name,
    required this.floorNumber,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'hallId': hallId,
        'name': name,
        'floorNumber': floorNumber,
        if (description != null) 'description': description,
      };

  factory CreateFloorDto.fromJson(Map<String, dynamic> json) => CreateFloorDto(
        hallId: json['hallId'] as String,
        name: json['name'] as String,
        floorNumber: (json['floorNumber'] as num?)?.toInt() ?? 0,
        description: json['description'] as String?,
      );

  void validate() {
    if (hallId.trim().isEmpty) {
      throw Exception('Hall ID is required');
    }
    if (name.trim().isEmpty) {
      throw Exception('Floor name is required');
    }
    if (floorNumber < 0) {
      throw Exception('Floor number must be >= 0');
    }
  }
}

/// Update Floor DTO
class UpdateFloorDto {
  final String? name;
  final int? floorNumber;
  final String? description;

  UpdateFloorDto({
    this.name,
    this.floorNumber,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (floorNumber != null) 'floorNumber': floorNumber,
        if (description != null) 'description': description,
      };

  void validate() {
    if (floorNumber != null && floorNumber! < 0) {
      throw Exception('Floor number must be >= 0');
    }
  }
}

/// Create Room DTO
class CreateRoomDto {
  final String floorId;
  final String name;
  final int capacity; // Must be >= 1
  final String? description;

  CreateRoomDto({
    required this.floorId,
    required this.name,
    required this.capacity,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'floorId': floorId,
        'name': name,
        'capacity': capacity,
        if (description != null) 'description': description,
      };

  factory CreateRoomDto.fromJson(Map<String, dynamic> json) => CreateRoomDto(
        floorId: json['floorId'] as String,
        name: json['name'] as String,
        capacity: (json['capacity'] as num?)?.toInt() ?? 1,
        description: json['description'] as String?,
      );

  void validate() {
    if (floorId.trim().isEmpty) {
      throw Exception('Floor ID is required');
    }
    if (name.trim().isEmpty) {
      throw Exception('Room name is required');
    }
    if (capacity < 1) {
      throw Exception('Room capacity must be >= 1');
    }
    if (capacity > 10) {
      throw Exception('Room capacity cannot exceed 10');
    }
  }
}

/// Update Room DTO
class UpdateRoomDto {
  final String? name;
  final int? capacity;
  final String? description;

  UpdateRoomDto({
    this.name,
    this.capacity,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (capacity != null) 'capacity': capacity,
        if (description != null) 'description': description,
      };

  void validate() {
    if (capacity != null) {
      if (capacity! < 1) {
        throw Exception('Room capacity must be >= 1');
      }
      if (capacity! > 10) {
        throw Exception('Room capacity cannot exceed 10');
      }
    }
  }
}

/// Response DTOs
class HostelResponseDto {
  final String id;
  final String name;
  final String type;
  final String gender;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  HostelResponseDto({
    required this.id,
    required this.name,
    required this.type,
    required this.gender,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'gender': gender,
        if (description != null) 'description': description,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class HallResponseDto {
  final String id;
  final String hostelId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  HallResponseDto({
    required this.id,
    required this.hostelId,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hostelId': hostelId,
        'name': name,
        if (description != null) 'description': description,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class FloorResponseDto {
  final String id;
  final String hallId;
  final String name;
  final int floorNumber;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  FloorResponseDto({
    required this.id,
    required this.hallId,
    required this.name,
    required this.floorNumber,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hallId': hallId,
        'name': name,
        'floorNumber': floorNumber,
        if (description != null) 'description': description,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class RoomResponseDto {
  final String id;
  final String floorId;
  final String name;
  final int capacity;
  final int occupied;
  final bool isAvailable;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoomResponseDto({
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'floorId': floorId,
        'name': name,
        'capacity': capacity,
        'occupied': occupied,
        'isAvailable': isAvailable,
        if (description != null) 'description': description,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

