import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mess_model.dart';
import '../models/mess_bill_model.dart';
import 'cloudinary_service.dart';

final messServiceProvider = Provider((ref) => MessService());

class MessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get menu for a specific date
  Future<MessMenu?> getMenuForDate(DateTime date) async {
    try {
      final query = await _firestore
          .collection('mess_menus')
          .where('date',
              isEqualTo:
                  Timestamp.fromDate(DateTime(date.year, date.month, date.day)))
          .where('isActive', isEqualTo: true)
          .get();

      if (query.docs.isNotEmpty) {
        return MessMenu.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Real-time stream of menu for a specific date. Used by admin so
  /// changes (add / edit / delete) reflect instantly without manual refresh.
  ///
  /// IMPORTANT: documents in `mess_menus` are keyed by `yyyy-MM-dd` (the same
  /// scheme used by addOrUpdateMenuItem), so we look up by document ID — not
  /// by the `date` field — to avoid Timestamp equality issues caused by
  /// hour/minute components in the saved value.
  Stream<MessMenu?> getMenuForDateStream(DateTime date) {
    final docId =
        DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
    return _firestore
        .collection('mess_menus')
        .doc(docId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      // Respect the isActive flag (defaults to true if missing)
      if ((data['isActive'] ?? true) != true) return null;
      return MessMenu.fromFirestore(doc);
    });
  }

  // Get menu for current week
  Stream<List<MessMenu>> getCurrentWeekMenu() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    return _firestore
        .collection('mess_menus')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .where('date', isLessThan: Timestamp.fromDate(endOfWeek))
        .snapshots()
        .map((snapshot) {
      // Filter isActive in memory to avoid composite index requirement
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            return data['isActive'] == true;
          })
          .map((doc) => MessMenu.fromFirestore(doc))
          .toList();
    });
  }

  // Add or update menu item
  Future<void> addOrUpdateMenuItem(DateTime date, MessMenuItem item) async {
    try {
      final docRef = _firestore
          .collection('mess_menus')
          .doc(date.toIso8601String().split('T')[0]);

      final docSnapshot = await docRef.get();
      MessMenu menu;

      if (docSnapshot.exists) {
        menu = MessMenu.fromFirestore(docSnapshot);
      } else {
        menu = MessMenu(
          date: date,
          meals: {
            MealType.breakfast: [],
            MealType.lunch: [],
            MealType.dinner: [],
          },
          isActive: true,
        );
      }

      // Remove existing item with the same ID if it exists
      menu.meals[item.type] =
          menu.meals[item.type]?.where((i) => i.id != item.id).toList() ?? [];
      menu.meals[item.type]?.add(item);

      await docRef.set(menu.toMap());
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error adding/updating menu item: $e');
      rethrow;
    }
  }

  // Remove menu item
  Future<void> removeMenuItem(DateTime date, MessMenuItem item) async {
    try {
      final docRef = _firestore
          .collection('mess_menus')
          .doc(date.toIso8601String().split('T')[0]);

      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final menu = MessMenu.fromFirestore(docSnapshot);
        menu.meals[item.type] =
            menu.meals[item.type]?.where((i) => i.id != item.id).toList() ?? [];
        await docRef.set(menu.toMap());
      }
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error removing menu item: $e');
      rethrow;
    }
  }

  Future<String> saveMenuItem(MessMenuItem item, {Object? image}) async {
    try {
      String? imageUrl;
      if (image != null) {
        imageUrl = await CloudinaryService.uploadImage(file: image);
      }

      final itemData = item.toMap();
      if (imageUrl != null) {
        itemData['imageUrl'] = imageUrl;
      }

      if (item.id.isEmpty) {
        // Create new item
        final docRef = await _firestore.collection('menu_items').add(itemData);
        return docRef.id;
      } else {
        // Update existing item
        await _firestore.collection('menu_items').doc(item.id).update(itemData);
        return item.id;
      }
    } catch (e) {
      rethrow;
    }
  }

  // Create or update menu for a date
  Future<void> createOrUpdateMenu(MessMenu menu) async {
    try {
      final docId = menu.date.toIso8601String().split('T')[0];
      await _firestore.collection('mess_menus').doc(docId).set(
            menu.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('Error creating/updating menu: $e');
      rethrow;
    }
  }

  // Delete menu item
  Future<void> deleteMenuItem(String itemId) async {
    try {
      await _firestore.collection('menu_items').doc(itemId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Get all menu items
  Stream<List<MessMenuItem>> getAllMenuItems() {
    return _firestore.collection('menu_items').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => MessMenuItem.fromFirestore(doc)).toList());
  }

  // Toggle menu item availability
  Future<void> toggleMenuItemAvailability(
      String itemId, bool isAvailable) async {
    try {
      await _firestore
          .collection('menu_items')
          .doc(itemId)
          .update({'isAvailable': isAvailable});
    } catch (e) {
      rethrow;
    }
  }

  // Get menu items by type
  Stream<List<MessMenuItem>> getMenuItemsByType(MealType type) {
    return _firestore
        .collection('menu_items')
        .where('type', isEqualTo: type.toString())
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessMenuItem.fromFirestore(doc))
            .toList());
  }

  // Get mess schedule PDF URL
  Future<String?> getSchedulePdf() async {
    try {
      final doc = await _firestore
          .collection('mess_settings')
          .doc('schedule_pdf')
          .get();
      if (doc.exists) {
        return doc.data()?['pdfUrl'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting schedule PDF: $e');
      return null;
    }
  }

  // Stream mess schedule PDF URL for real-time updates
  Stream<String?> getSchedulePdfStream() {
    return _firestore
        .collection('mess_settings')
        .doc('schedule_pdf')
        .snapshots()
        .map((doc) => doc.data()?['pdfUrl'] as String?);
  }

  // Upload and update mess schedule PDF (admin only)
  Future<void> updateSchedulePdf(Object? pdfFile) async {
    try {
      final pdfUrl = await _uploadSchedulePdf(pdfFile);
      await _firestore.collection('mess_settings').doc('schedule_pdf').set({
        'pdfUrl': pdfUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating schedule PDF: $e');
      rethrow;
    }
  }

  // Upload schedule PDF to storage
  Future<String> _uploadSchedulePdf(Object? pdfFile) async {
    try {
      final pdfUrl = await CloudinaryService.uploadImage(
        file: pdfFile,
        resourceType: 'raw',
      );
      if (pdfUrl == null) {
        throw Exception('Schedule PDF upload cancelled');
      }
      return pdfUrl;
    } catch (e) {
      rethrow;
    }
  }
  // --- Mess Billing Section ---

  // Add amount to student's mess bill
  // This is idempotent: it will only increment the bill once for a given attendanceId
  Future<void> addToBill({
    required String studentId,
    required double amount,
    required String attendanceId,
    String? studentName, // Optional, used for creating new bill
  }) async {
    try {
      final billRef = _firestore.collection('mess_bills').doc(studentId);
      final mealRef = billRef.collection('billed_meals').doc(attendanceId);
      
      await _firestore.runTransaction((transaction) async {
        final mealDoc = await transaction.get(mealRef);
        
        // If this meal has already been billed, do nothing
        if (mealDoc.exists) {
          debugPrint('Meal $attendanceId already billed for student $studentId');
          return;
        }

        final billDoc = await transaction.get(billRef);
        
        if (billDoc.exists) {
          final currentAmount = (billDoc.data()?['amount'] ?? 0).toDouble();
          transaction.update(billRef, {
            'amount': currentAmount + amount,
            'lastUpdated': FieldValue.serverTimestamp(),
            if (studentName != null) 'studentName': studentName,
          });
        } else {
          // Fetch student profile to get roll number
          final profileDoc = await _firestore.collection('profiles').doc(studentId).get();
          final userData = profileDoc.data();
          final rollNumber = userData?['arnRollNumber'] ?? userData?['rollNumber'] ?? 'N/A';
          final name = studentName ?? userData?['name'] ?? 'Unknown';

          transaction.set(billRef, {
            'studentId': studentId,
            'studentName': name,
            'rollNumber': rollNumber,
            'amount': amount,
            'lastUpdated': FieldValue.serverTimestamp(),
            'status': 'unpaid',
          });
        }

        // Mark this meal as billed in the same transaction
        transaction.set(mealRef, {
          'billedAt': FieldValue.serverTimestamp(),
          'amount': amount,
        });
      });
    } catch (e) {
      debugPrint('Error adding to mess bill: $e');
      rethrow;
    }
  }

  // Process a payment (supports partial payments)
  Future<void> processPayment(String studentId, double paidAmount) async {
    try {
      final billRef = _firestore.collection('mess_bills').doc(studentId);
      
      await _firestore.runTransaction((transaction) async {
        final billDoc = await transaction.get(billRef);
        if (!billDoc.exists) return;

        final currentAmount = (billDoc.data()?['amount'] ?? 0).toDouble();
        final newAmount = (currentAmount - paidAmount).clamp(0.0, double.infinity);
        
        transaction.update(billRef, {
          'amount': newAmount,
          'status': newAmount <= 0 ? 'paid' : 'unpaid',
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // If payment covers the full bill, we clear billed_meals to reset the cycle
        if (newAmount <= 0) {
          final billedMeals = await billRef.collection('billed_meals').get();
          for (final doc in billedMeals.docs) {
            transaction.delete(doc.reference);
          }
        }
      });
    } catch (e) {
      debugPrint('Error processing mess payment: $e');
      rethrow;
    }
  }

  // Reset bill amount to 0 (Admin approves payment)
  // Also clears the billed_meals subcollection so future attendance
  // marks are counted fresh (idempotency tracking is reset).
  Future<void> resetBill(String studentId) async {
    try {
      final billRef = _firestore.collection('mess_bills').doc(studentId);

      // 1. Clear all billed_meals entries so idempotency resets
      final billedMeals = await billRef.collection('billed_meals').get();
      final batch = _firestore.batch();
      for (final doc in billedMeals.docs) {
        batch.delete(doc.reference);
      }

      // 2. Reset the bill amount to 0
      batch.update(billRef, {
        'amount': 0,
        'status': 'paid',
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Error resetting mess bill: $e');
      rethrow;
    }
  }

  // Get specific student's bill
  Stream<MessBillModel?> getStudentBill(String studentId) {
    return _firestore
        .collection('mess_bills')
        .doc(studentId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return MessBillModel.fromFirestore(doc);
      }
      return null;
    });
  }

  // Get all bills (Admin)
  Stream<List<MessBillModel>> getAllBills() {
    return _firestore.collection('mess_bills').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => MessBillModel.fromFirestore(doc)).toList();
    });
  }
}
