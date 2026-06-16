import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'mess_service.dart';

final messAttendanceServiceProvider = Provider((ref) => MessAttendanceService(ref));

class MessAttendanceService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MessAttendanceService(this._ref);

  CollectionReference<Map<String, dynamic>> get _globalAttendanceCollection =>
      _firestore.collection('messAttendance');
  CollectionReference<Map<String, dynamic>> _studentAttendanceCollection(String studentId) =>
      _firestore.collection('profiles').doc(studentId).collection('messAttendance');

  /// Mark student attendance for a specific date and meal
  /// Once marked, attendance cannot be changed
  Future<void> markAttendance({
    required String studentId,
    required String studentName,
    required DateTime date,
    required String mealType, // 'breakfast', 'lunch', 'dinner'
    required bool isPresent,
  }) async {
    try {
      final dateOnly = DateTime(date.year, date.month, date.day);
      final dateStr = DateFormat('yyyy-MM-dd').format(dateOnly);
      final attendanceId = '${studentId}_${dateStr}_$mealType';

      // Check if attendance has already been marked (locked)
      // Use student's subcollection for more robust permission handling on existence check
      final existingDoc = await _studentAttendanceCollection(studentId).doc(attendanceId).get();
      if (existingDoc.exists) {
        final existingData = existingDoc.data()!;
        // Check if it's locked (has been marked before)
        if (existingData['isLocked'] == true) {
          throw Exception('Attendance for this meal has already been marked and cannot be changed');
        }
      }

      final data = {
        'studentId': studentId,
        'studentName': studentName,
        'date': Timestamp.fromDate(dateOnly),
        'mealType': mealType,
        'isPresent': isPresent,
        'isLocked': true, // Lock attendance once marked
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final batch = _firestore.batch();
      batch.set(
        _globalAttendanceCollection.doc(attendanceId),
        data,
        SetOptions(merge: true),
      );
      batch.set(
        _studentAttendanceCollection(studentId).doc(attendanceId),
        data,
        SetOptions(merge: true),
      );
      await batch.commit();

      // If present, add cost to bill
      // We assume a fixed cost for now, e.g., 200 PKR per meal
      // In a real app, this could be fetched from the menu item or settings
      if (isPresent) {
        try {
          // Use Riverpod ref to read MessService
          // Note: Since we are in a Provider, we can use the ref passed to constructor
          // However, reading a provider inside a method called by UI is fine.
          // But MessAttendanceService is created with a Ref.
          final messService = _ref.read(messServiceProvider);
          await messService.addToBill(
            studentId: studentId, 
            amount: 200.0, // Fixed cost per meal
            studentName: studentName,
            attendanceId: attendanceId,
          );
        } catch (e) {
          // Log error but don't fail the attendance marking?
          // Or strictly fail? Let's log for now to avoid blocking attendance if billing fails temporarily
          // but rethrow if critical.
          // Ideally billing and attendance should be same transaction but they are different collections/services.
          print('Error adding to bill: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to mark attendance: $e');
    }
  }

  /// Check if attendance is locked (already marked) for a specific date and meal
  Future<bool> isAttendanceLocked({
    required String studentId,
    required DateTime date,
    required String mealType,
  }) async {
    try {
      final dateOnly = DateTime(date.year, date.month, date.day);
      final dateStr = DateFormat('yyyy-MM-dd').format(dateOnly);
      final attendanceId = '${studentId}_${dateStr}_$mealType';

      // Check student subcollection instead of global for better permissions
      final doc = await _studentAttendanceCollection(studentId).doc(attendanceId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      return data['isLocked'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Get attendance status for a specific date and meal
  Future<Map<String, dynamic>?> getAttendanceStatus({
    required String studentId,
    required DateTime date,
    required String mealType,
  }) async {
    try {
      final dateOnly = DateTime(date.year, date.month, date.day);
      final dateStr = DateFormat('yyyy-MM-dd').format(dateOnly);
      final attendanceId = '${studentId}_${dateStr}_$mealType';

      // Use student subcollection
      final doc = await _studentAttendanceCollection(studentId).doc(attendanceId).get();
      if (!doc.exists) return null;

      return doc.data();
    } catch (e) {
      return null;
    }
  }

  /// Get student's attendance for a date range
  Stream<List<Map<String, dynamic>>> getStudentAttendance(
    String studentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();

    final startBoundary = Timestamp.fromDate(DateTime(start.year, start.month, start.day));
    final endBoundary = Timestamp.fromDate(DateTime(end.year, end.month, end.day));

    return _studentAttendanceCollection(studentId)
        .where('date', isGreaterThanOrEqualTo: startBoundary)
        .where('date', isLessThanOrEqualTo: endBoundary)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  /// Get attendance statistics for a student
  Future<Map<String, dynamic>> getStudentAttendanceStats(String studentId) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      final snapshot = await _studentAttendanceCollection(studentId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      int totalMeals = 0;
      int presentMeals = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalMeals++;
        if (data['isPresent'] == true) {
          presentMeals++;
        }
      }

      return {
        'totalMeals': totalMeals,
        'presentMeals': presentMeals,
        'absentMeals': totalMeals - presentMeals,
        'attendanceRate': totalMeals > 0 ? (presentMeals / totalMeals) * 100 : 0.0,
      };
    } catch (e) {
      throw Exception('Failed to get attendance stats: $e');
    }
  }

  /// Get all attendance records (admin)
  Stream<List<Map<String, dynamic>>> getAllAttendance({
    DateTime? startDate,
    DateTime? endDate,
    String? mealType,
  }) {
    Query query = _firestore.collection('messAttendance');

    if (startDate != null) {
      query = query.where('date',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day)));
    }

    if (endDate != null) {
      query = query.where('date',
          isLessThanOrEqualTo:
              Timestamp.fromDate(DateTime(endDate.year, endDate.month, endDate.day)));
    }

    if (mealType != null) {
      query = query.where('mealType', isEqualTo: mealType);
    }

    return query.orderBy('date', descending: true).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) {
          final docData = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
          final data = Map<String, dynamic>.from(docData);
          data['id'] = doc.id;
          return data;
        }).toList());
  }

  /// Get attendance summary for admin dashboard
  Future<Map<String, dynamic>> getAttendanceSummary({
    DateTime? date,
  }) async {
    try {
      final targetDate = date ?? DateTime.now();
      final dateStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final dateEnd = dateStart.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('messAttendance')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dateStart))
          .where('date', isLessThan: Timestamp.fromDate(dateEnd))
          .get();

      int totalRecords = 0;
      int presentCount = 0;
      final mealStats = <String, Map<String, int>>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalRecords++;
        final mealType = data['mealType'] as String? ?? 'unknown';
        final isPresent = data['isPresent'] as bool? ?? false;

        if (isPresent) {
          presentCount++;
        }

        if (!mealStats.containsKey(mealType)) {
          mealStats[mealType] = {'total': 0, 'present': 0};
        }
        mealStats[mealType]!['total'] = (mealStats[mealType]!['total'] ?? 0) + 1;
        if (isPresent) {
          mealStats[mealType]!['present'] = (mealStats[mealType]!['present'] ?? 0) + 1;
        }
      }

      return {
        'date': dateStart.toIso8601String(),
        'totalRecords': totalRecords,
        'presentCount': presentCount,
        'absentCount': totalRecords - presentCount,
        'attendanceRate': totalRecords > 0 ? (presentCount / totalRecords) * 100 : 0.0,
        'mealStats': mealStats,
      };
    } catch (e) {
      throw Exception('Failed to get attendance summary: $e');
    }
  }
}

