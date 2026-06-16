import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service.dart';
import 'local_notification_service.dart';
import '../models/hostel_model.dart';
import '../models/hall_floor_room_model.dart' show RoomModel, BedModel;
import '../models/payment_model.dart';
import 'hall_floor_room_service.dart';
import 'cloudinary_service.dart';
import 'pdf_challan_service.dart';
import '../widgets/auth_gate.dart';

class HostelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();
  static const int _accommodationCooldownMonths = 6;

  // Submit hostel application
  // Uses studentId as document ID - NO reads before writing
  // Works for both first-time submissions and updates
  Future<void> submitHostelApplication({
    required String studentId,
    required String studentName,
    required String studentEmail,
    required String rollNumber,
    required String academicYear,
    required RoomType roomType,
    required String city,
    Object? cnicImage,
  }) async {
    try {
      // CRITICAL: Ensure auth is ready before accessing Firestore
      // This prevents permission-denied errors on Web and Mobile
      debugPrint('[HostelService] Checking auth readiness before Firestore access...');
      final currentUser = await getCurrentUserWithAuthCheck();
      
      if (currentUser == null) {
        throw Exception('Authentication required. Please sign in again.');
      }
      
      // Verify the studentId matches the authenticated user
      if (currentUser.uid != studentId) {
        throw Exception('User ID mismatch. Please sign in again.');
      }
      
      // CRITICAL: On Web, explicitly get the ID token to ensure it's attached to Firestore requests
      // This forces Firestore to use the current auth state
      if (kIsWeb) {
        try {
          final idToken = await currentUser.getIdToken(true); // Force refresh
          if (idToken != null) {
            debugPrint('[HostelService] ID token obtained for Firestore. Token length: ${idToken.length}');
          } else {
            debugPrint('[HostelService] Warning: ID token is null');
          }
          // Small delay to ensure token propagation
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          debugPrint('[HostelService] Warning: Could not get ID token: $e');
          // Continue anyway - might still work
        }
      }
      
      debugPrint('[HostelService] Auth verified. User: ${currentUser.uid}');
      
      // Upload CNIC image to Cloudinary if provided
      String? cnicImageUrl;
      if (cnicImage != null) {
        cnicImageUrl = await CloudinaryService.uploadImage(file: cnicImage);
      }

      // Use studentId as the document ID for direct writes
      // This ensures one application per student and avoids read-before-write
      final applicationId = studentId;
      
      final applicationData = {
        'id': applicationId,
        'studentId': studentId,
        'studentName': studentName,
        'studentEmail': studentEmail,
        'rollNumber': rollNumber,
        'academicYear': academicYear,
        'roomType': roomType.toString().split('.').last,
        'city': city,
        'cnicImageUrl': cnicImageUrl ?? '',
        'status': 'pending',
        'feeAmount': HostelApplicationModel.getFeeAmount(roomType),
        'feeChallanUrl': '',
        'feeConfirmed': false,
        'selectedRoomId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      debugPrint('[HostelService] Writing application to hostelApplications/$applicationId');
      debugPrint('[HostelService] Data: $applicationData');

      // Direct write with merge - creates if not exists, updates if exists
      await _firestore
          .collection('hostelApplications')
          .doc(applicationId)
          .set(applicationData, SetOptions(merge: true));
      
      debugPrint('[HostelService] Application submitted successfully!');
    } catch (e, stackTrace) {
      debugPrint('[HostelService] Error submitting application: $e');
      debugPrint('[HostelService] Stack trace: $stackTrace');
      
      // Provide more specific error messages
      if (e.toString().contains('permission-denied')) {
        throw Exception('Permission denied. Please ensure you are signed in and try again.');
      } else if (e.toString().contains('unauthenticated')) {
        throw Exception('Authentication required. Please sign in again.');
      } else {
        throw Exception('Failed to submit application: $e');
      }
    }
  }

  DateTime _calculateCooldownExpiry(DateTime from) {
    return DateTime(
      from.year,
      from.month + _accommodationCooldownMonths,
      from.day,
      from.hour,
      from.minute,
      from.second,
    );
  }

  // Get user's hostel application
  // Returns null if no application exists (this is valid for first-time users)
  Future<HostelApplicationModel?> getUserApplication(String studentId) async {
    try {
      final querySnapshot = await _firestore
          .collection('hostelApplications')
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return HostelApplicationModel.fromFirestore(querySnapshot.docs.first);
      }
      // No application found - this is normal for first-time submissions
      return null;
    } catch (e) {
      // Log the error but return null instead of throwing
      // This allows first-time submissions to proceed
      debugPrint('Error fetching user application (may be first-time user): $e');
      return null;
    }
  }

  // Get user's hostel application stream
  Stream<HostelApplicationModel?> getUserApplicationStream(String studentId) {
    return _firestore
        .collection('hostelApplications')
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return HostelApplicationModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    });
  }

  // Get all hostels (for admin)
  Stream<List<HostelModel>> getAllHostels() {
    return _firestore.collection('hostels').snapshots().map((snapshot) {
      final hostels =
          snapshot.docs.map((doc) => HostelModel.fromFirestore(doc)).toList();
      // Sort in-memory to avoid index requirement
      hostels.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return hostels;
    });
  }

  // Update hostel (admin only)
  Future<void> updateHostel({
    required String hostelId,
    required String name,
    required String gender,
    required int totalFloors,
    required String description,
  }) async {
    try {
      await _firestore.collection('hostels').doc(hostelId).update({
        'name': name,
        'gender': gender,
        'totalFloors': totalFloors,
        'description': description,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to update hostel: $e');
    }
  }

  // Delete hostel (admin only)
  Future<void> deleteHostel(String hostelId) async {
    try {
      await _firestore.collection('hostels').doc(hostelId).delete();
    } catch (e) {
      throw Exception('Failed to delete hostel: $e');
    }
  }

  // Get all applications (for admin)
  Stream<List<HostelApplicationModel>> getAllApplications() {
    return _firestore
        .collection('hostelApplications')
        .snapshots()
        .map((snapshot) {
      final applications = snapshot.docs
          .map((doc) => HostelApplicationModel.fromFirestore(doc))
          .toList();
      // Sort in-memory to avoid index requirement
      applications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return applications;
    });
  }

  // Update application status (admin only)
  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
  }) async {
    try {
      await _firestore
          .collection('hostelApplications')
          .doc(applicationId)
          .update({
        'status': status,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to update application status: $e');
    }
  }

  // Generate fee challan (admin only)
  Future<void> generateFeeChallan({
    required String applicationId,
    required String bankName,
    required String accountNumber,
    required String accountTitle,
  }) async {
    try {
      // CRITICAL: Check both payments and feeChallans collections to prevent duplicates
      // Also check application status to avoid race conditions
      final appDoc = await _firestore
          .collection('hostelApplications')
          .doc(applicationId)
          .get();

      if (!appDoc.exists) {
        throw Exception('Application not found');
      }

      final appData = appDoc.data()!;

      // 1. Strict Duplicate Check:
      // If status indicates challan is already generated, STOP immediately.
      if (appData['status'] == 'fee_challan_generated' ||
          appData['status'] == 'fee_confirmed') {
        final existingChallanUrl = appData['feeChallanUrl'] as String?;
        if (existingChallanUrl != null && existingChallanUrl.isNotEmpty) {
          debugPrint(
              '[HostelService] Challan already generated (status check). applicationId: $applicationId');
          return; // Silent return to avoid throwing error for double-click
        }
      }

      // 2. Strict Payment Check:
      // Check if a payment record already exists for this application.
      final existingPaymentQuery = await _firestore
          .collection('payments')
          .where('applicationId', isEqualTo: applicationId)
          .where('type', isEqualTo: PaymentType.hostelFee.toString())
          .limit(1)
          .get();

      if (existingPaymentQuery.docs.isNotEmpty) {
        debugPrint(
            '[HostelService] Payment record already exists. applicationId: $applicationId');
        // Ensure application status is synced
        if (appData['status'] != 'fee_confirmed') {
          await _firestore
              .collection('hostelApplications')
              .doc(applicationId)
              .update({
            'status': 'fee_challan_generated',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return; // Silent return
      }

      // 3. Mark as processing/generated immediately to prevent race conditions
      // We do this BEFORE the expensive PDF generation or network calls.
      await _firestore
          .collection('hostelApplications')
          .doc(applicationId)
          .update({
        'status': 'fee_challan_generated',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Application already fetched above, parse it
      final application = HostelApplicationModel.fromFirestore(appDoc);

      // Get student details directly from the application model (avoids extra read & permission errors)
      final studentName = application.studentName;
      final studentEmail = application.studentEmail;
      final arnRollNumber = application.rollNumber;

      // Import PdfChallanService
      final pdfChallanService = PdfChallanService();

      // Generate challan with bank details
      final challanUrl = await pdfChallanService.generateFeeChallan(
        application: application,
        studentName: studentName,
        studentEmail: studentEmail,
        arnRollNumber: arnRollNumber,
        bankName: bankName,
        accountNumber: accountNumber,
        accountTitle: accountTitle,
      );

      // Create payment record for student
      final dueDate = DateTime.now().add(const Duration(days: 7));
      final docRef = await _firestore.collection('payments').add({
        'userId': application.studentId,
        'applicationId': applicationId,
        'type': PaymentType.hostelFee
            .toString(), // Store as 'PaymentType.hostelFee'
        'amount': application.feeAmount,
        'description':
            'Hostel Fee - ${application.roomType.toString().split('.').last}',
        'status': PaymentStatus.pending
            .toString(), // Store as 'PaymentStatus.pending'
        'dueDate': Timestamp.fromDate(dueDate),
        'challanUrl': challanUrl,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountTitle': accountTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata': {
          'applicationId': applicationId,
          'roomType': application.roomType.toString().split('.').last,
        },
      });

      // Create feePayments record for admin to accept later, mimicking createPayment logic
      await _firestore.collection('feePayments').add({
        'paymentId': docRef.id,
        'applicationId': applicationId,
        'userId': application.studentId,
        'amount': application.feeAmount,
        'paymentType': PaymentType.hostelFee.toString(),
        'status': PaymentStatus.pending.toString(),
        'adminAccepted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send notification to student about challan
      try {
        final notification = NotificationModel(
          id: '',
          userId: application.studentId,
          title: 'Fee Challan Generated',
          message:
              'Your hostel fee challan has been generated. Please check the payments section to view and pay.',
          type: 'challan_generated',
          isRead: false,
          createdAt: DateTime.now(),
          data: {
            'applicationId': applicationId,
            'paymentId':
                applicationId, // Using applicationId as payment identifier
            'amount': application.feeAmount,
          },
        );
        await NotificationService().createNotification(notification);
        await LocalNotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: notification.title,
          body: notification.message,
        );
      } catch (e) {
        // Log but don't fail the challan generation if notification fails
        debugPrint('Failed to send challan notification: $e');
      }
    } catch (e) {
      throw Exception('Failed to generate fee challan: $e');
    }
  }

  // Confirm fee payment (admin only)
  Future<void> confirmFeePayment(String applicationId,
      {String? feePaymentId}) async {
    try {
      bool specificUpdateSuccess = false;
      String? actualPaymentId;

      // If a specific fee payment ID is provided (e.g. from FeePaymentsScreen), update it directly
      if (feePaymentId != null) {
        try {
          // get the feePayment doc to find the associated paymentId
          final feeDoc = await _firestore.collection('feePayments').doc(feePaymentId).get();
          if (feeDoc.exists) {
            actualPaymentId = feeDoc.data()?['paymentId'] as String?;
          }

          await _firestore.collection('feePayments').doc(feePaymentId).update({
            'adminAccepted': true,
            'acceptedAt': DateTime.now(),
            'status': 'completed', // Ensure status is marked completed
          });
          specificUpdateSuccess = true;
          debugPrint('Successfully confirmed fee payment: $feePaymentId');
        } catch (e) {
          debugPrint('Failed to update specific feePayment $feePaymentId: $e');
          // If the specific update fails, we should probably stop and let the user know
          throw Exception('Failed to update the specific payment record: $e');
        }
      }

      bool isGymFee = false;
      if (actualPaymentId != null) {
        final paymentDoc = await _firestore.collection('payments').doc(actualPaymentId).get();
        if (paymentDoc.exists) {
          final pData = paymentDoc.data()!;
          if (pData['type'] == 'PaymentType.gymFee') {
            isGymFee = true;
            // update underlying payment status
            await _firestore.collection('payments').doc(actualPaymentId).update({
              'status': 'PaymentStatus.completed',
              'paidAt': FieldValue.serverTimestamp(),
            });
          } else {
             // For hostel fees, sync status to completed
             await _firestore.collection('payments').doc(actualPaymentId).update({
              'status': 'PaymentStatus.completed',
              'paidAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      if (isGymFee) {
        // Update Gym Registration
        await _firestore
            .collection('gymRegistrations')
            .doc(applicationId)
            .update({
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Update application status
        await _firestore
            .collection('hostelApplications')
            .doc(applicationId)
            .update({
          'status': 'fee_confirmed',
          'feeConfirmed': true,
          'updatedAt': DateTime.now(),
        });
      }

      // Mark related feePayments as adminAccepted (legacy/cleanup logic)
      final feeQuery = await _firestore
          .collection('feePayments')
          .where('applicationId', isEqualTo: applicationId)
          .get();

      int updatedCount = 0;
      for (final doc in feeQuery.docs) {
        if (feePaymentId != null && doc.id == feePaymentId) continue;

        try {
          await _firestore.collection('feePayments').doc(doc.id).update({
            'adminAccepted': true,
            'acceptedAt': DateTime.now(),
            'status': 'completed',
          });
          updatedCount++;
        } catch (e) {
          debugPrint('Failed to update feePayments ${doc.id}: $e');
        }
      }

      if (feePaymentId != null && !specificUpdateSuccess) {
        throw Exception('Failed to confirm the specific payment record.');
      }

      // Notify student
      if (isGymFee) {
        final appDoc = await _firestore.collection('gymRegistrations').doc(applicationId).get();
        if (appDoc.exists) {
          final appData = appDoc.data()!;
          final studentId = appData['studentId'] as String?;
          if (studentId != null) {
            final notification = NotificationModel(
              id: '',
              userId: studentId,
              title: 'Gym Payment Accepted',
              message: 'Your Gym fee payment has been confirmed! Your gym pass is now active.',
              type: 'payment_accepted',
              isRead: false,
              createdAt: DateTime.now(),
              data: {'registrationId': applicationId},
            );
            try {
              await NotificationService().createNotification(notification);
              await LocalNotificationService.showNotification(
                id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
                title: notification.title,
                body: notification.message,
              );
            } catch (_) {}
          }
        }
      } else {
        final appDoc = await _firestore
            .collection('hostelApplications')
            .doc(applicationId)
            .get();
        if (appDoc.exists) {
          final appData = appDoc.data()!;
          final studentId = appData['studentId'] as String?;
          if (studentId != null) {
            final notification = NotificationModel(
              id: '',
              userId: studentId,
              title: 'Payment Accepted',
              message:
                  'Your hostel fee has been accepted by administration. You may now select a room.',
              type: 'payment_accepted',
              isRead: false,
              createdAt: DateTime.now(),
              data: {'applicationId': applicationId},
            );
            try {
              await NotificationService().createNotification(notification);
              await LocalNotificationService.showNotification(
                id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
                title: notification.title,
                body: notification.message,
              );
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to confirm fee payment: $e');
    }
  }

  // Get available hostels based on gender
  Stream<List<HostelModel>> getHostelsByGender(String gender) {
    // No where clause to avoid index requirement - filter in memory instead
    return _firestore.collection('hostels').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => HostelModel.fromFirestore(doc))
          .where((h) =>
              h.gender.toLowerCase() ==
              gender.toLowerCase()) // Filter in memory
          .toList();
    });
  }

  /// Get hostels appropriate for a student based on their year and gender.
  /// Implements hall allotment rules:
  /// - Jinnah Hall for 1st/2nd years
  /// - Iqbal Hall for 3rd/4th years
  /// - Auto-redirects if halls are full
  Stream<List<HostelModel>> getHostelsForStudent(
      String year, String gender) async* {
    try {
      // Fetch all halls and find ones whose assignedYears contains this year.
      // Year stored as calendar year string (e.g. '2026') OR academic label
      // (e.g. '1st Year'). We match either way, and also always fall back to
      // showing all gender-matching hostels if no year-specific hall found.
      final allHallsSnap = await _firestore.collection('halls').get();

      // Try to match by exact year string first, then fall back to all halls
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> hallsSnap =
          allHallsSnap.docs.where((doc) {
        final assignedYears =
            (doc.data()['assignedYears'] as List<dynamic>?) ?? [];
        return assignedYears.contains(year);
      });

      // If no halls matched the year, use all halls (show all options)
      if (hallsSnap.isEmpty) {
        hallsSnap = allHallsSnap.docs;
      }
      final hostelIds = <String>{};
      final hallMap = <String, String>{}; // hallId -> hallName

      for (final h in hallsSnap) {
        final data = h.data();
        final hallName = data['name'] as String? ?? '';
        if (data['hostelId'] != null) {
          final hostelId = data['hostelId'] as String;
          hostelIds.add(hostelId);
          hallMap[hostelId] = hallName;
        }
      }

      if (hostelIds.isNotEmpty) {
        // Query hostels by id set and gender
        final idsList = hostelIds.toList();
        final chunks = <List<String>>[];
        for (var i = 0; i < idsList.length; i += 10) {
          chunks.add(idsList.sublist(
              i, i + 10 > idsList.length ? idsList.length : i + 10));
        }

        final results = <HostelModel>[];
        for (final chunk in chunks) {
          final q = await _firestore
              .collection('hostels')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          // Filter by gender in memory to avoid index requirement
          results.addAll(q.docs
              .map((d) => HostelModel.fromFirestore(d))
              .where((h) => h.gender.toLowerCase() == gender.toLowerCase())
              .toList());
        }

        // Check if all rooms in the first hostel are full → redirect to next
        if (results.isNotEmpty) {
          final preferredHostel = results.first;

          // Check room availability (simplified - in production, check actual room counts)
          final isFull = await _isHostelFull(preferredHostel.id);
          if (isFull && results.length > 1) {
            // Redirect to alternative hall
            final alternativeHall = results.firstWhere(
              (h) => h.id != preferredHostel.id,
              orElse: () => results.first,
            );
            yield [alternativeHall];
            return;
          }
        }

        yield results;
        return;
      }

      // Fallback: hostels by gender
      yield* getHostelsByGender(gender);
    } catch (e) {
      // On error, fallback to gender filter
      yield* getHostelsByGender(gender);
    }
  }

  /// Check if a hostel is full (no available rooms)
  Future<bool> _isHostelFull(String hostelId) async {
    try {
      // Get all floors for this hostel
      final floorsSnap = await _firestore
          .collection('floors')
          .where('hostelId', isEqualTo: hostelId)
          .get();

      int totalRooms = 0;
      int occupiedRooms = 0;

      for (var floorDoc in floorsSnap.docs) {
        final roomsSnap = await _firestore
            .collection('rooms')
            .where('floorId', isEqualTo: floorDoc.id)
            .get();

        for (var roomDoc in roomsSnap.docs) {
          final roomData = roomDoc.data();
          totalRooms++;
          final occupied = roomData['occupied'] as int? ?? 0;
          final capacity = roomData['capacity'] as int? ?? 1;
          if (occupied >= capacity) {
            occupiedRooms++;
          }
        }
      }

      return totalRooms > 0 && occupiedRooms >= totalRooms;
    } catch (e) {
      // Log error for debugging but don't block user flow
      // ignore: avoid_print
      debugPrint('Error checking hostel availability: $e');
      return false; // If error, assume not full to allow user to proceed
    }
  }

  // Get floors for a hostel
  // NOTE: getFloorsForHostel and getRoomsForFloor have been moved to HallFloorRoomService
  // Use HallFloorRoomService.getFloorsForHall() and HallFloorRoomService.getRoomsForFloor() instead

  // Assign room to student
  Future<void> assignRoomToStudent({
    required String applicationId,
    required String roomId,
  }) async {
    try {
      // Get application to get student ID
      final appDoc = await _firestore
          .collection('hostelApplications')
          .doc(applicationId)
          .get();
      if (!appDoc.exists) {
        throw Exception('Application not found');
      }
      final appData = appDoc.data()!;
      final studentId = appData['studentId'] as String;

      // Get available bed in the room using HallFloorRoomService
      final hallService = HallFloorRoomService();
      final beds = await _firestore
          .collection('beds')
          .where('roomId', isEqualTo: roomId)
          .get();

      if (beds.docs.isEmpty) {
        throw Exception(
            'No beds found in this room. Please ensure beds are created for this room before assignment.');
      }

      // Find first available bed
      BedModel? availableBed;
      for (var bedDoc in beds.docs) {
        final bed = BedModel.fromFirestore(bedDoc);
        if (!bed.isOccupied) {
          availableBed = bed;
          break;
        }
      }

      if (availableBed == null) {
        throw Exception(
            'No available beds in this room. All beds are currently occupied.');
      }

      // Assign bed to student (this will automatically update room occupancy)
      await hallService.assignBedToStudent(
        bedId: availableBed.id,
        studentId: studentId,
      );

      // Update student's profile with cooldown so they can't reapply for 6 months
      final cooldownUntil = _calculateCooldownExpiry(DateTime.now());
      await _firestore.collection('profiles').doc(studentId).set({
        'accommodationCooldownUntil': Timestamp.fromDate(cooldownUntil),
        'hasActiveAccommodation': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update application with selected room
      await _firestore
          .collection('hostelApplications')
          .doc(applicationId)
          .update({
        'selectedRoomId': roomId,
        'status': 'room_assigned',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to assign room: $e');
    }
  }

  // Create a room request (student selects room => admin approval required)
  Future<void> createRoomRequest({
    required String applicationId,
    required String studentId,
    required String roomId,
  }) async {
    try {
      // Check if student already has a pending or approved room request
      final existingRequests = await _firestore
          .collection('roomRequests')
          .where('studentId', isEqualTo: studentId)
          .where('status', whereIn: ['pending', 'approved']).get();

      if (existingRequests.docs.isNotEmpty) {
        throw Exception(
            'You already have a pending or approved room request. Please wait for it to be processed.');
      }

      // Check if student already has a room assigned
      final application = await getUserApplication(studentId);
      if (application != null && application.status == 'room_assigned') {
        throw Exception(
            'You already have a room assigned. You cannot request another room.');
      }

      final requestId = _uuid.v4();
      await _firestore.collection('roomRequests').doc(requestId).set({
        'applicationId': applicationId,
        'studentId': studentId,
        'roomId': roomId,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create room request: $e');
    }
  }

  // Stream pending room requests (admin)
  Stream<List<Map<String, dynamic>>> getPendingRoomRequests() {
    return _firestore
        .collection('roomRequests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
      // Sort in memory to avoid index requirement
      docs.sort((a, b) {
        final aTime = a['requestedAt'] as Timestamp?;
        final bTime = b['requestedAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });
      return docs;
    });
  }

  // Approve a pending room request (admin). This assigns the room and updates request status.
  Future<void> approveRoomRequest(String requestId,
      {String? adminNote, String? processedBy}) async {
    try {
      final doc =
          await _firestore.collection('roomRequests').doc(requestId).get();
      if (!doc.exists) throw Exception('Request not found');
      final data = doc.data()!;
      final applicationId = data['applicationId'] as String;
      final roomId = data['roomId'] as String;
      final studentId = data['studentId'] as String?;

      // assign room
      await assignRoomToStudent(applicationId: applicationId, roomId: roomId);

      // update request with admin note and processor info
      await _firestore.collection('roomRequests').doc(requestId).update({
        'status': 'approved',
        'processedAt': FieldValue.serverTimestamp(),
        if (adminNote != null) 'adminNote': adminNote,
        if (processedBy != null) 'processedBy': processedBy,
      });

      // send notification to student
      if (studentId != null) {
        final messageBody = adminNote != null && adminNote.isNotEmpty
            ? 'Your room request has been approved by administration. Note: $adminNote'
            : 'Your room request has been approved by administration.';

        final notification = NotificationModel(
          id: '',
          userId: studentId,
          title: 'Room Assigned',
          message: messageBody,
          type: 'room_approved',
          isRead: false,
          createdAt: DateTime.now(),
          data: {
            'requestId': requestId,
            'roomId': roomId,
            'applicationId': applicationId,
            if (adminNote != null) 'adminNote': adminNote
          },
        );
        try {
          await NotificationService().createNotification(notification);
        } catch (e) {
          // ignore: avoid_print
          debugPrint('Failed to create room approval notification: $e');
        }

        try {
          await LocalNotificationService.showNotification(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title: notification.title,
            body: notification.message,
          );
        } catch (_) {}
      }
    } catch (e) {
      throw Exception('Failed to approve room request: $e');
    }
  }

  Future<void> rejectRoomRequest(String requestId, {String? reason}) async {
    try {
      final doc =
          await _firestore.collection('roomRequests').doc(requestId).get();
      if (!doc.exists) throw Exception('Request not found');
      final data = doc.data()!;
      final studentId = data['studentId'] as String?;

      await _firestore.collection('roomRequests').doc(requestId).update({
        'status': 'rejected',
        'processedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'adminNote': reason,
      });

      if (studentId != null) {
        final messageBody = (reason != null && reason.isNotEmpty)
            ? reason
            : 'Your room request has been rejected by administration.';

        final notification = NotificationModel(
          id: '',
          userId: studentId,
          title: 'Room Request Rejected',
          message: messageBody,
          type: 'room_rejected',
          isRead: false,
          createdAt: DateTime.now(),
          data: {
            'requestId': requestId,
            if (reason != null) 'adminNote': reason
          },
        );
        try {
          await NotificationService().createNotification(notification);
        } catch (e) {
          // ignore: avoid_print
          debugPrint('Failed to create room rejection notification: $e');
        }

        try {
          await LocalNotificationService.showNotification(
            id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title: notification.title,
            body: notification.message,
          );
        } catch (_) {}
      }
    } catch (e) {
      throw Exception('Failed to reject room request: $e');
    }
  }

  // Create hostel (admin only)
  Future<void> createHostel({
    required String name,
    required String gender,
    required int totalFloors,
    required String description,
  }) async {
    try {
      final hostelId = _uuid.v4();
      final hostel = HostelModel(
        id: hostelId,
        name: name,
        gender: gender,
        totalFloors: totalFloors,
        description: description,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('hostels')
          .doc(hostelId)
          .set(hostel.toFirestore());
    } catch (e) {
      throw Exception('Failed to create hostel: $e');
    }
  }

  // NOTE: createFloor and createRoom methods have been moved to HallFloorRoomService
  // Use HallFloorRoomService.createFloor() and HallFloorRoomService.createRoom() instead

  // Get occupancy statistics
  Future<Map<String, dynamic>> getOccupancyStats() async {
    try {
      final hostelsSnapshot = await _firestore.collection('hostels').get();
      final roomsSnapshot = await _firestore.collection('rooms').get();

      Map<String, dynamic> stats = {};

      for (var hostelDoc in hostelsSnapshot.docs) {
        final hostel = HostelModel.fromFirestore(hostelDoc);
        final hostelRooms = roomsSnapshot.docs
            .map((doc) => RoomModel.fromFirestore(doc))
            .where((room) => room.floorId.contains(hostel.id))
            .toList();

        final totalRooms = hostelRooms.length;
        final occupiedRooms =
            hostelRooms.where((room) => room.occupied > 0).length;

        stats[hostel.name] = {
          'totalRooms': totalRooms,
          'occupiedRooms': occupiedRooms,
          'availableRooms': totalRooms - occupiedRooms,
          'occupancyRate':
              totalRooms > 0 ? (occupiedRooms / totalRooms) * 100 : 0,
        };
      }

      return stats;
    } catch (e) {
      throw Exception('Failed to get occupancy stats: $e');
    }
  }

  // Get occupancy statistics stream
  Stream<Map<String, dynamic>> getOccupancyStatsStream() {
    return _firestore
        .collection('hostels')
        .snapshots()
        .asyncMap((hostelsSnapshot) async {
      final roomsSnapshot = await _firestore.collection('rooms').get();

      Map<String, dynamic> stats = {};

      for (var hostelDoc in hostelsSnapshot.docs) {
        final hostel = HostelModel.fromFirestore(hostelDoc);
        final hostelRooms = roomsSnapshot.docs
            .map((doc) => RoomModel.fromFirestore(doc))
            .where((room) => room.floorId.contains(hostel.id))
            .toList();

        final totalRooms = hostelRooms.length;
        final occupiedRooms =
            hostelRooms.where((room) => room.occupied > 0).length;

        stats[hostel.name] = {
          'totalRooms': totalRooms,
          'occupiedRooms': occupiedRooms,
          'availableRooms': totalRooms - occupiedRooms,
          'occupancyRate':
              totalRooms > 0 ? (occupiedRooms / totalRooms) * 100 : 0,
        };
      }

      return stats;
    });
  }

  Future<void> startNewSemester({
    required String startedByUid,
    int cooldownMonths = _accommodationCooldownMonths,
  }) async {
    try {
      final collectionsToClear = [
        'roomRequests',
        'roomSwaps',
        'beds',
        'rooms',
        'floors',
        'halls',
        'hostels',
        'hostelApplications',
      ];

      for (final path in collectionsToClear) {
        await _clearCollection(path);
      }

      await _resetProfilesForNewSemester();

      // Additional collections to clear for a full wipe out
      final additionalCollections = [
        'payments',
        'feePayments',
        'messAttendance',
        'gymRegistrations',
        'complaints',
        'notifications'
      ];

      for (final path in additionalCollections) {
        await _clearCollection(path);
      }

      await _firestore.collection('systemSettings').doc('semester').set({
        'currentSemesterId': _uuid.v4(),
        'startedAt': FieldValue.serverTimestamp(),
        'startedBy': startedByUid,
        'cooldownMonths': cooldownMonths,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to start new semester: $e');
    }
  }

  Future<void> _clearCollection(String path, {int batchSize = 200}) async {
    while (true) {
      final snapshot = await _firestore.collection(path).limit(batchSize).get();
      if (snapshot.docs.isEmpty) {
        break;
      }

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < batchSize) {
        break;
      }
    }
  }

  Future<void> _resetProfilesForNewSemester({int batchSize = 200}) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    do {
      snapshot = await _firestore.collection('profiles').limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.set(
          doc.reference,
          {
            'accommodationCooldownUntil': FieldValue.delete(),
            'hasActiveAccommodation': false,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } while (snapshot.docs.length == batchSize);
  }

  // Create a room swap request (student-initiated, one-time only)
  Future<void> createSwapRequest({
    required String fromRoomId,
    required String toRoomId,
    required String studentId,
    required String reason,
  }) async {
    try {
      // Check if student already has a pending or approved swap request
      final existingSwap = await _firestore
          .collection('roomSwaps')
          .where('studentId', isEqualTo: studentId)
          .where('status', whereIn: ['pending', 'approved'])
          .limit(1)
          .get();

      if (existingSwap.docs.isNotEmpty) {
        throw Exception(
            'You already have an active swap request. Only one swap is allowed.');
      }

      // Create swap request
      final swapId = _uuid.v4();
      await _firestore.collection('roomSwaps').doc(swapId).set({
        'fromRoomId': fromRoomId,
        'toRoomId': toRoomId,
        'studentId': studentId,
        'reason': reason,
        'status': 'pending',
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });

      // Notify admin
      try {
        final notification = NotificationModel(
          id: '',
          userId: 'admin',
          title: 'New Room Swap Request',
          message: 'A student has requested a room swap',
          type: 'room_swap',
          isRead: false,
          createdAt: DateTime.now(),
          data: {'swapId': swapId},
        );
        await NotificationService().createNotification(notification);
        await LocalNotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: notification.title,
          body: notification.message,
        );
      } catch (_) {}
    } catch (e) {
      throw Exception('Failed to create swap request: $e');
    }
  }

  // Get pending swap requests (admin)
  Stream<List<Map<String, dynamic>>> getPendingSwapRequests() {
    return _firestore
        .collection('roomSwaps')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
      // Sort in-memory by createdAt to avoid index requirement
      requests.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });
      return requests;
    });
  }

  // Approve swap request (admin)
  Future<void> approveSwapRequest(String swapId, {String? adminNote}) async {
    try {
      final doc = await _firestore.collection('roomSwaps').doc(swapId).get();
      if (!doc.exists) throw Exception('Swap request not found');

      final data = doc.data()!;
      final fromRoomId = data['fromRoomId'] as String;
      final toRoomId = data['toRoomId'] as String;
      final studentId = data['studentId'] as String;

      // Perform the swap
      // 1. Remove student from old room
      await _firestore.collection('rooms').doc(fromRoomId).update({
        'occupied': FieldValue.increment(-1),
        'isAvailable': true,
      });

      // 2. Add student to new room
      await _firestore.collection('rooms').doc(toRoomId).update({
        'occupied': FieldValue.increment(1),
        'isAvailable': false,
      });

      // 3. Update application with new room
      final appQuery = await _firestore
          .collection('hostelApplications')
          .where('studentId', isEqualTo: studentId)
          .where('status', isEqualTo: 'room_assigned')
          .limit(1)
          .get();

      if (appQuery.docs.isNotEmpty) {
        await _firestore
            .collection('hostelApplications')
            .doc(appQuery.docs.first.id)
            .update({
          'selectedRoomId': toRoomId,
          'updatedAt': DateTime.now(),
        });
      }

      // 4. Update swap request status
      await _firestore.collection('roomSwaps').doc(swapId).update({
        'status': 'approved',
        'adminNote': adminNote ?? '',
        'processedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify student
      try {
        final notification = NotificationModel(
          id: '',
          userId: studentId,
          title: 'Room Swap Approved',
          message: 'Your room swap request has been approved.',
          type: 'swap_approved',
          isRead: false,
          createdAt: DateTime.now(),
          data: {'swapId': swapId},
        );
        await NotificationService().createNotification(notification);
        await LocalNotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: notification.title,
          body: notification.message,
        );
      } catch (_) {}
    } catch (e) {
      throw Exception('Failed to approve swap request: $e');
    }
  }

  // Reject swap request (admin)
  Future<void> rejectSwapRequest(String swapId, {String? reason}) async {
    try {
      final doc = await _firestore.collection('roomSwaps').doc(swapId).get();
      if (!doc.exists) throw Exception('Swap request not found');

      final data = doc.data()!;
      final studentId = data['studentId'] as String;

      await _firestore.collection('roomSwaps').doc(swapId).update({
        'status': 'rejected',
        'rejectionReason': reason ?? '',
        'processedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify student
      try {
        final message = reason != null && reason.isNotEmpty
            ? 'Your room swap request has been rejected. Reason: $reason'
            : 'Your room swap request has been rejected.';
        final notification = NotificationModel(
          id: '',
          userId: studentId,
          title: 'Room Swap Rejected',
          message: message,
          type: 'swap_rejected',
          isRead: false,
          createdAt: DateTime.now(),
          data: {'swapId': swapId},
        );
        await NotificationService().createNotification(notification);
        await LocalNotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: notification.title,
          body: notification.message,
        );
      } catch (_) {}
    } catch (e) {
      throw Exception('Failed to reject swap request: $e');
    }
  }
}

final hostelServiceProvider = Provider<HostelService>((ref) {
  return HostelService();
});
