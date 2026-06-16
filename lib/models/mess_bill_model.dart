import 'package:cloud_firestore/cloud_firestore.dart';

class MessBillModel {
  final String id; // Usually the studentId for 1-to-1 mapping
  final String studentId;
  final String studentName;
  final String rollNumber;
  final double amount;
  final DateTime lastUpdated;
  final String status; // 'unpaid', 'paid' (though we reset to 0, status acts as a flag)

  MessBillModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.amount,
    required this.lastUpdated,
    this.status = 'unpaid',
  });

  factory MessBillModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessBillModel(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      rollNumber: data['rollNumber'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'unpaid',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'rollNumber': rollNumber,
      'amount': amount,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'status': status,
    };
  }
}
