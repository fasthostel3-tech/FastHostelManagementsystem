import 'package:cloud_firestore/cloud_firestore.dart';

enum MaintenanceStatus { pending, inProgress, completed, rejected }

class MaintenanceRequest {
  final String id;
  final String userId;
  final String roomNumber;
  final String issue;
  final String description;
  final MaintenanceStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? staffNotes;
  final List<String>? images;

  MaintenanceRequest({
    required this.id,
    required this.userId,
    required this.roomNumber,
    required this.issue,
    required this.description,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.staffNotes,
    this.images,
  });

  factory MaintenanceRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MaintenanceRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      roomNumber: data['roomNumber'] ?? '',
      issue: data['issue'] ?? '',
      description: data['description'] ?? '',
      status: MaintenanceStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => MaintenanceStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      staffNotes: data['staffNotes'],
      images: List<String>.from(data['images'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'roomNumber': roomNumber,
      'issue': issue,
      'description': description,
      'status': status.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'staffNotes': staffNotes,
      'images': images,
    };
  }
}