import 'package:cloud_firestore/cloud_firestore.dart';

class HostelModel {
  final String id;
  final String name;
  final String gender;
  final int totalFloors;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  HostelModel({
    required this.id,
    required this.name,
    required this.gender,
    required this.totalFloors,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HostelModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return HostelModel(
      id: doc.id,
      name: data['name'] ?? '',
      gender: data['gender'] ?? '',
      totalFloors: data['totalFloors'] ?? 0,
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'gender': gender,
      'totalFloors': totalFloors,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

// Note: FloorModel and RoomModel have been moved to hall_floor_room_model.dart
// Import them from there if needed

enum RoomType { single, double, shared }

class HostelApplicationModel {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String rollNumber;
  final String academicYear;
  final RoomType roomType;
  final String city;
  final String cnicImageUrl;
  final String status;
  final double feeAmount;
  final String feeChallanUrl;
  final bool feeConfirmed;
  final String? selectedRoomId;
  final DateTime createdAt;
  final DateTime updatedAt;

  HostelApplicationModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.rollNumber,
    required this.academicYear,
    required this.roomType,
    required this.city,
    required this.cnicImageUrl,
    required this.status,
    required this.feeAmount,
    required this.feeChallanUrl,
    required this.feeConfirmed,
    this.selectedRoomId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HostelApplicationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return HostelApplicationModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentEmail: data['studentEmail'] ?? '',
      rollNumber: data['rollNumber'] ?? '',
      academicYear: data['academicYear'] ?? '',
      roomType: RoomType.values.firstWhere(
        (e) => e.toString() == 'RoomType.${data['roomType']}',
        orElse: () => RoomType.shared,
      ),
      city: data['city'] ?? '',
      cnicImageUrl: data['cnicImageUrl'] ?? '',
      status: data['status'] ?? 'pending',
      feeAmount: (data['feeAmount'] ?? 0.0).toDouble(),
      feeChallanUrl: data['feeChallanUrl'] ?? '',
      feeConfirmed: data['feeConfirmed'] ?? false,
      selectedRoomId: data['selectedRoomId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'rollNumber': rollNumber,
      'academicYear': academicYear,
      'roomType': roomType.toString().split('.').last,
      'city': city,
      'cnicImageUrl': cnicImageUrl,
      'status': status,
      'feeAmount': feeAmount,
      'feeChallanUrl': feeChallanUrl,
      'feeConfirmed': feeConfirmed,
      'selectedRoomId': selectedRoomId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static double getFeeAmount(RoomType roomType) {
    switch (roomType) {
      case RoomType.single:
        return 70000.0;
      case RoomType.double:
        return 67000.0;
      case RoomType.shared:
        return 42000.0;
    }
  }
}


