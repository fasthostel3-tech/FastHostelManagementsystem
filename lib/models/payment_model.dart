import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus { pending, completed, failed, refunded }
enum PaymentType { hostelFee, messFee, securityDeposit, fine, gymFee }

class PaymentModel {
  final String id;
  final String userId;
  final double amount;
  final PaymentType type;
  final PaymentStatus status;
  final String description;
  final DateTime dueDate;
  final DateTime? paidAt;
  final String? transactionId;
  final Map<String, dynamic>? metadata;
  final String? challanUrl;
  final String? bankName;
  final String? accountNumber;
  final String? accountTitle;

  PaymentModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.status,
    required this.description,
    required this.dueDate,
    this.paidAt,
    this.transactionId,
    this.metadata,
    this.challanUrl,
    this.bankName,
    this.accountNumber,
    this.accountTitle,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      type: PaymentType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => PaymentType.hostelFee,
      ),
      status: PaymentStatus.values.firstWhere(
        (e) => e.toString() == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      description: data['description'] ?? '',
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
      transactionId: data['transactionId'],
      metadata: data['metadata'],
      challanUrl: data['challanUrl'],
      bankName: data['bankName'],
      accountNumber: data['accountNumber'],
      accountTitle: data['accountTitle'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type.toString(),
      'status': status.toString(),
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'transactionId': transactionId,
      'metadata': metadata,
      'challanUrl': challanUrl,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountTitle': accountTitle,
    };
  }
}