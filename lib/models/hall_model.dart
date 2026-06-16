import 'package:cloud_firestore/cloud_firestore.dart';

class HallModel {
  final String id;
  final String name;
  final String? hostelId;
  final List<String> assignedYears; // e.g., ['Freshman','Sophomore']
  final DateTime createdAt;

  HallModel({
    required this.id,
    required this.name,
    this.hostelId,
    required this.assignedYears,
    required this.createdAt,
  });

  factory HallModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HallModel(
      id: doc.id,
      name: data['name'] ?? '',
      hostelId: data['hostelId'] as String?,
      assignedYears: List<String>.from(data['assignedYears'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (hostelId != null) 'hostelId': hostelId,
      'assignedYears': assignedYears,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
