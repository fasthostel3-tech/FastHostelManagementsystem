import 'package:flutter_test/flutter_test.dart';
import 'package:fast_hostel_system/models/payment_model.dart';

void main() {
  group('PaymentModel Tests', () {
    late PaymentModel payment;
    final now = DateTime.now();

    setUp(() {
      payment = PaymentModel(
        id: 'P1',
        userId: 'U1',
        amount: 67000.0,
        type: PaymentType.hostelFee,
        status: PaymentStatus.pending,
        description: 'Hostel Fee for Fall 2025',
        dueDate: now.add(const Duration(days: 7)),
      );
    });

    test('Payment initialization with correct values', () {
      expect(payment.id, 'P1');
      expect(payment.userId, 'U1');
      expect(payment.amount, 67000.0);
      expect(payment.type, PaymentType.hostelFee);
      expect(payment.status, PaymentStatus.pending);
      expect(payment.description, 'Hostel Fee for Fall 2025');
      expect(payment.dueDate.isAfter(now), true);
      expect(payment.paidAt, isNull);
      expect(payment.transactionId, isNull);
      expect(payment.metadata, isNull);
    });

    test('Payment with transaction details', () {
      final paidPayment = PaymentModel(
        id: 'P2',
        userId: 'U1',
        amount: 42000.0,
        type: PaymentType.messFee,
        status: PaymentStatus.completed,
        description: 'Mess Fee for October 2025',
        dueDate: now,
        paidAt: now,
        transactionId: 'T123',
        metadata: {
          'paymentMethod': 'bank_transfer',
          'bankName': 'Test Bank',
        },
      );

      expect(paidPayment.status, PaymentStatus.completed);
      expect(paidPayment.paidAt, now);
      expect(paidPayment.transactionId, 'T123');
      expect(paidPayment.metadata!['paymentMethod'], 'bank_transfer');
      expect(paidPayment.metadata!['bankName'], 'Test Bank');
    });

    test('Supported payment types', () {
      expect(PaymentType.values, contains(PaymentType.hostelFee));
      expect(PaymentType.values, contains(PaymentType.messFee));
      expect(PaymentType.values, contains(PaymentType.securityDeposit));
      expect(PaymentType.values, contains(PaymentType.fine));
    });

    test('All payment status values', () {
      expect(PaymentStatus.values, contains(PaymentStatus.pending));
      expect(PaymentStatus.values, contains(PaymentStatus.completed));
      expect(PaymentStatus.values, contains(PaymentStatus.failed));
      expect(PaymentStatus.values, contains(PaymentStatus.refunded));
    });
  });
}