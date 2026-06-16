import 'package:cloud_firestore/cloud_firestore.dart';

enum RoomType { single, double, triple }
enum RoomStatus { available, occupied, maintenance, reserved }

class RoomModel {
  final String id;
  final String number;
  final RoomType type;
  final RoomStatus status;
  final int floor;
  final int capacity;
  final int occupiedCount;
  final double price;
  final List<String> occupants;
  final List<String>? facilities;
  final Map<String, dynamic>? metadata;

  RoomModel({
    required this.id,
    required this.number,
    required this.type,
    required this.status,
    required this.floor,
    required this.capacity,
    required this.occupiedCount,
    required this.price,
    required this.occupants,
    this.facilities,
    this.metadata,
  });

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoomModel(
      id: doc.id,
      number: data['number'] ?? '',
      type: RoomType.values.firstWhere(
        (t) => t.toString() == data['type'],
        orElse: () => RoomType.single,
      ),
      status: RoomStatus.values.firstWhere(
        (s) => s.toString() == data['status'],
        orElse: () => RoomStatus.available,
      ),
      floor: data['floor'] ?? 0,
      capacity: data['capacity'] ?? 1,
      occupiedCount: data['occupiedCount'] ?? 0,
      price: (data['price'] ?? 0).toDouble(),
      occupants: List<String>.from(data['occupants'] ?? []),
      facilities: data['facilities'] != null
          ? List<String>.from(data['facilities'])
          : null,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'type': type.toString(),
      'status': status.toString(),
      'floor': floor,
      'capacity': capacity,
      'occupiedCount': occupiedCount,
      'price': price,
      'occupants': occupants,
      if (facilities != null) 'facilities': facilities,
      if (metadata != null) 'metadata': metadata,
    };
  }

  bool get isAvailable => status == RoomStatus.available;
  bool get isFull => occupiedCount >= capacity;

  RoomModel copyWith({
    String? number,
    RoomType? type,
    RoomStatus? status,
    int? floor,
    int? capacity,
    int? occupiedCount,
    double? price,
    List<String>? occupants,
    List<String>? facilities,
    Map<String, dynamic>? metadata,
  }) {
    return RoomModel(
      id: id,
      number: number ?? this.number,
      type: type ?? this.type,
      status: status ?? this.status,
      floor: floor ?? this.floor,
      capacity: capacity ?? this.capacity,
      occupiedCount: occupiedCount ?? this.occupiedCount,
      price: price ?? this.price,
      occupants: occupants ?? this.occupants,
      facilities: facilities ?? this.facilities,
      metadata: metadata ?? this.metadata,
    );
  }
}