import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment_model.dart';
import 'cloudinary_service.dart';
import '../widgets/auth_gate.dart';

final paymentServiceProvider = Provider((ref) => PaymentService());

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload a fee challan image to Cloudinary and create a feePayments record
  /// that the admin can review/accept. This keeps payment -> feePayments
  /// creation logic centralized.
  Future<void> uploadFeeChallanProof({
    required String paymentId,
    required String userId,
    required String? applicationId,
    required Object? imageFile,
    double? paidAmount,
  }) async {
    try {
      // CRITICAL: Ensure auth is ready before accessing Firestore
      // This prevents permission-denied errors on Web and Mobile
      debugPrint('[PaymentService] Checking auth readiness before Firestore access...');
      final currentUser = await getCurrentUserWithAuthCheck();
      
      if (currentUser == null) {
        throw Exception('Authentication required. Please sign in again.');
      }
      
      // Verify the userId matches the authenticated user
      if (currentUser.uid != userId) {
        throw Exception('User ID mismatch. Please sign in again.');
      }
      
      // CRITICAL: On Web, explicitly get the ID token to ensure it's attached to Firestore requests
      if (kIsWeb) {
        try {
          final idToken = await currentUser.getIdToken(true); // Force refresh
          if (idToken != null) {
            debugPrint('[PaymentService] ID token obtained for Firestore. Token length: ${idToken.length}');
          } else {
            debugPrint('[PaymentService] Warning: ID token is null');
          }
          // Small delay to ensure token propagation
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('[PaymentService] Warning: Could not get ID token: $e');
          // Continue anyway - might still work
        }
      }
      
      debugPrint('[PaymentService] Auth verified. User: ${currentUser.uid}');
      
      // Look up payment amount and type for reference
      double proofAmount = 0;
      String proofType = PaymentType.hostelFee.toString();
      try {
        final paymentDoc =
            await _firestore.collection('payments').doc(paymentId).get();
        if (paymentDoc.exists) {
          final data = paymentDoc.data();
          if (data != null) {
            if (data['amount'] != null) {
              proofAmount = (data['amount'] ?? 0).toDouble();
            }
            if (data['type'] != null) {
              proofType = data['type'].toString();
            }
          }
        }
      } catch (e) {
        debugPrint('[PaymentService] Warning: Could not fetch payment details: $e');
        // Non-fatal: keep default values
      }

      // Upload image to Cloudinary
      debugPrint('[PaymentService] Uploading payment proof image to Cloudinary...');
      final secureUrl = await CloudinaryService.uploadImage(file: imageFile);
      if (secureUrl == null) {
        throw Exception('Fee challan upload cancelled');
      }
      debugPrint('[PaymentService] Image uploaded successfully: $secureUrl');

      // Try to find and UPDATE the existing feePayments record for this paymentId
      // (created automatically when the challan was generated).
      // If none found, create a new record.
      debugPrint('[PaymentService] Looking for existing feePayments record...');
      final existingQuery = await _firestore
          .collection('feePayments')
          .where('paymentId', isEqualTo: paymentId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        // Update the existing record with the proof URL
        final existingDoc = existingQuery.docs.first;
        debugPrint('[PaymentService] Updating existing feePayments doc: ${existingDoc.id}');
        await existingDoc.reference.update({
          'proofUrl': secureUrl,
          'amount': paidAmount ?? proofAmount, // Allow updating amount if partial payment
          'status': 'pending',
          'adminAccepted': false,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      } else {
        // No existing record — create a new feePayments record
        debugPrint('[PaymentService] No existing record found. Creating new feePayments record...');
        await _firestore.collection('feePayments').add({
          'paymentId': paymentId,
          'applicationId': applicationId,
          'userId': userId,
          'amount': paidAmount ?? proofAmount, // Use provided amount or default
          'paymentType': proofType,
          'proofUrl': secureUrl,
          'status': 'pending',
          'adminAccepted': false,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      // ── Update source status for better student feedback ───────────────────
      if (applicationId != null && applicationId.isNotEmpty) {
        if (proofType == PaymentType.gymFee.toString()) {
          // Update gym registration status to 'awaiting_confirmation' 
          // (This is a NEW status we'll handle in the UI)
          try {
            await _firestore
                .collection('gymRegistrations')
                .doc(applicationId)
                .update({'status': 'payment_uploaded'});
                
            // Also sync to profile subcollection
            await _firestore
                .collection('profiles')
                .doc(userId)
                .collection('gymRegistrations')
                .doc(applicationId)
                .update({'status': 'payment_uploaded'});
          } catch (e) {
            debugPrint('[PaymentService] Warning: Could not update gym registration status: $e');
          }
        } else if (proofType == PaymentType.hostelFee.toString()) {
            // Optional: hostel application status update could go here too
        }
      }

      debugPrint('[PaymentService] Payment proof uploaded successfully!');
    } catch (e, stackTrace) {
      debugPrint('[PaymentService] Error uploading payment proof: $e');
      debugPrint('[PaymentService] Stack trace: $stackTrace');
      
      // Provide more specific error messages
      if (e.toString().contains('permission-denied')) {
        throw Exception('Permission denied. Please ensure you are signed in and try again.');
      } else if (e.toString().contains('unauthenticated')) {
        throw Exception('Authentication required. Please sign in again.');
      } else {
        throw Exception('Failed to upload fee challan proof: $e');
      }
    }
  }

  // Get user payments
  Stream<List<PaymentModel>> getUserPayments(String userId) {
    return _firestore
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .orderBy('dueDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PaymentModel.fromFirestore(doc))
            .toList());
  }

  // Create payment
  Future<String> createPayment(PaymentModel payment) async {
    try {
      // Validate/inject bank details if omitted
      String? finalBankName = payment.bankName;
      String? finalAccountNumber = payment.accountNumber;
      String? finalAccountTitle = payment.accountTitle;
      
      if (finalBankName == null || finalBankName.isEmpty ||
          finalAccountNumber == null || finalAccountNumber.isEmpty) {
        try {
          String settingsDocName = 'bankDetailsAccommodation';
          if (payment.type == PaymentType.messFee) {
            settingsDocName = 'bankDetailsMess';
          } else if (payment.type == PaymentType.gymFee) {
            settingsDocName = 'bankDetailsGym';
          }

          var settingsDoc = await _firestore.collection('settings').doc(settingsDocName).get();
          
          if (settingsDoc.exists && settingsDoc.data() != null) {
            final data = settingsDoc.data()!;
            finalBankName = data['bankName'] ?? finalBankName;
            finalAccountNumber = data['accountNumber'] ?? finalAccountNumber;
            finalAccountTitle = data['accountTitle'] ?? finalAccountTitle;
          } else if (settingsDocName != 'bankDetailsAccommodation') {
            // Fallback to accommodation (legacy 'bankDetails' logic handled by admin creating accommodation ones)
            final fallbackDoc = await _firestore.collection('settings').doc('bankDetailsAccommodation').get();
            if (fallbackDoc.exists && fallbackDoc.data() != null) {
              final data = fallbackDoc.data()!;
              finalBankName = data['bankName'] ?? finalBankName;
              finalAccountNumber = data['accountNumber'] ?? finalAccountNumber;
              finalAccountTitle = data['accountTitle'] ?? finalAccountTitle;
            }
          }
        } catch (e) {
          debugPrint('Failed to load global bank details: $e');
        }
      }

      final paymentData = payment.toMap();
      paymentData['bankName'] = finalBankName;
      paymentData['accountNumber'] = finalAccountNumber;
      paymentData['accountTitle'] = finalAccountTitle;

      final docRef =
          await _firestore.collection('payments').add(paymentData);

      // Add an entry into a dedicated feePayments collection
      // so admin can accept uploaded challan payments.
      try {
        await _firestore.collection('feePayments').add({
          'paymentId': docRef.id,
          'applicationId': payment.metadata != null
              ? payment.metadata!['applicationId']
              : null,
          'userId': payment.userId,
          'amount': payment.amount,
          'paymentType': payment.type.toString(),
          'status': payment.status.toString(),
          'adminAccepted':
              payment.status == PaymentStatus.completed ? false : false,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
      } catch (e) {
        // non-fatal: log and continue
        debugPrint('Failed to create feePayments record: $e');
      }

      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // Update payment status
  Future<void> updatePaymentStatus(
    String paymentId,
    PaymentStatus status,
    String? transactionId,
  ) async {
    try {
      await _firestore.collection('payments').doc(paymentId).update({
        'status': status.toString(),
        'paidAt': status == PaymentStatus.completed
            ? Timestamp.fromDate(DateTime.now())
            : null,
        if (transactionId != null) 'transactionId': transactionId,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get payment details
  Future<PaymentModel?> getPaymentDetails(String paymentId) async {
    try {
      final doc = await _firestore.collection('payments').doc(paymentId).get();
      if (doc.exists) {
        return PaymentModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get due payments (payments due within the next 7 days)
  Stream<List<PaymentModel>> getDuePayments(String userId) {
    final now = DateTime.now();
    final dueDateLimit = now.add(const Duration(days: 7));

    return _firestore
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: PaymentStatus.pending.toString())
        .snapshots()
        .map((snapshot) {
      // Filter by dueDate in memory to avoid index requirement
      // Include payments due on or before (now + 7 days)
      return snapshot.docs
          .map((doc) => PaymentModel.fromFirestore(doc))
          .where((payment) {
        final dueDate = payment.dueDate;
        return dueDate.isBefore(dueDateLimit) ||
            dueDate.isAtSameMomentAs(dueDateLimit);
      }).toList();
    });
  }

  // Get payment statistics
  Future<Map<String, dynamic>> getPaymentStatistics(String userId) async {
    try {
      final payments = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .get();

      double totalPaid = 0;
      double totalPending = 0;
      int overdueCount = 0;

      for (var doc in payments.docs) {
        final payment = PaymentModel.fromFirestore(doc);
        if (payment.status == PaymentStatus.completed) {
          totalPaid += payment.amount;
        } else if (payment.status == PaymentStatus.pending) {
          totalPending += payment.amount;
          if (payment.dueDate.isBefore(DateTime.now())) {
            overdueCount++;
          }
        }
      }

      return {
        'totalPaid': totalPaid,
        'totalPending': totalPending,
        'overdueCount': overdueCount,
      };
    } catch (e) {
      rethrow;
    }
  }
}
