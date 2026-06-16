import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardServiceProvider = Provider((ref) => DashboardService());

enum DashboardFilter { today, thisWeek, thisMonth, thisYear, custom, all }

class DashboardDateRange {
  final DateTime start;
  final DateTime end;
  const DashboardDateRange({required this.start, required this.end});
}

class FinancialSummary {
  final double hostelFeesReceived;
  final double hostelFeesOutstanding;
  final double gymFeesReceived;
  final double gymFeesOutstanding;
  final double messFeesReceived;
  final double messFeesOutstanding;

  const FinancialSummary({
    required this.hostelFeesReceived,
    required this.hostelFeesOutstanding,
    required this.gymFeesReceived,
    required this.gymFeesOutstanding,
    required this.messFeesReceived,
    required this.messFeesOutstanding,
  });

  double get totalReceived =>
      hostelFeesReceived + gymFeesReceived + messFeesReceived;
  double get totalOutstanding =>
      hostelFeesOutstanding + gymFeesOutstanding + messFeesOutstanding;
}

class ApplicationStats {
  final int total;
  final int pending;
  final int approved;
  final int rejected;

  const ApplicationStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });
}

class StudentStats {
  final int total;
  final int active;
  final int hostelResidents;
  final int gymMembers;
  final int withOutstandingDues;

  const StudentStats({
    required this.total,
    required this.active,
    required this.hostelResidents,
    required this.gymMembers,
    required this.withOutstandingDues,
  });
}

class MonthlyRevenue {
  final String month;
  final double received;
  final double outstanding;

  const MonthlyRevenue({
    required this.month,
    required this.received,
    required this.outstanding,
  });
}

class MonthlyApplicationCount {
  final String month;
  final int total;
  final int approved;
  final int pending;
  final int rejected;

  const MonthlyApplicationCount({
    required this.month,
    required this.total,
    required this.approved,
    required this.pending,
    required this.rejected,
  });
}

class DashboardData {
  final FinancialSummary financial;
  final ApplicationStats applications;
  final StudentStats students;
  final List<MonthlyRevenue> monthlyRevenue;
  final List<MonthlyApplicationCount> monthlyApplications;
  final List<Map<String, dynamic>> recentApplications;
  final List<Map<String, dynamic>> recentGymRegistrations;
  final List<Map<String, dynamic>> recentPayments;
  final List<Map<String, dynamic>> recentMessBills;

  const DashboardData({
    required this.financial,
    required this.applications,
    required this.students,
    required this.monthlyRevenue,
    required this.monthlyApplications,
    required this.recentApplications,
    required this.recentGymRegistrations,
    required this.recentPayments,
    required this.recentMessBills,
  });
}

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DashboardDateRange getDateRange(
    DashboardFilter filter, {
    DashboardDateRange? custom,
  }) {
    final now = DateTime.now();
    switch (filter) {
      case DashboardFilter.today:
        return DashboardDateRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case DashboardFilter.thisWeek:
        final daysFromMonday = now.weekday - 1;
        final monday = now.subtract(Duration(days: daysFromMonday));
        return DashboardDateRange(
          start: DateTime(monday.year, monday.month, monday.day),
          end: now,
        );
      case DashboardFilter.thisMonth:
        return DashboardDateRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
      case DashboardFilter.thisYear:
        return DashboardDateRange(
          start: DateTime(now.year, 1, 1),
          end: now,
        );
      case DashboardFilter.custom:
        return custom ??
            DashboardDateRange(start: DateTime(now.year, 1, 1), end: now);
      case DashboardFilter.all:
        return DashboardDateRange(
          start: DateTime(2020, 1, 1),
          end: now.add(const Duration(days: 1)),
        );
    }
  }

  /// Safe Firestore fetch — returns empty QuerySnapshot on permission-denied.
  Future<QuerySnapshot<Map<String, dynamic>>> _safeGet(
      Query<Map<String, dynamic>> query) async {
    try {
      return await query.get();
    } on FirebaseException catch (e) {
      debugPrint('[DashboardService] ${e.code}: ${e.message}');
      // Return an empty snapshot by querying with limit(0)
      return await query.limit(0).get();
    } catch (e) {
      debugPrint('[DashboardService] fetch error: $e');
      return await query.limit(0).get();
    }
  }

  /// Returns a live dashboard stream. Re-emits whenever the payments collection
  /// changes; other collections are fetched via Future.wait for each emission.
  Stream<DashboardData> getDashboardStream({
    DashboardFilter filter = DashboardFilter.all,
    DashboardDateRange? customRange,
  }) {
    final range = getDateRange(filter, custom: customRange);

    // Use a safe stream that doesn't propagate permission errors
    final paymentsStream = _firestore
        .collection('payments')
        .snapshots()
        .handleError((e) {
      debugPrint('[DashboardService] payments stream error: $e');
    });

    return paymentsStream.asyncMap(
      (paymentsSnap) async {
        final results = await Future.wait([
          _safeGet(_firestore.collection('hostelApplications')),
          _safeGet(_firestore
              .collection('profiles')
              .where('role', isEqualTo: 'student')),
          _safeGet(_firestore.collection('gymRegistrations')),
          _safeGet(_firestore.collection('mess_bills')),
        ]);

        final appsSnap = results[0];
        final profilesSnap = results[1];
        final gymSnap = results[2];
        final messBillsSnap = results[3];

        // ── Payments aggregation ──────────────────────────────────────────
        double hostelReceived = 0, hostelOutstanding = 0;
        double gymReceived = 0, gymOutstanding = 0;
        double messReceived = 0, messOutstanding = 0;

        final recentPayments = <Map<String, dynamic>>[];

        // Monthly buckets for last 6 months
        final now = DateTime.now();
        final monthlyBuckets = <String, Map<String, double>>{};
        for (int i = 5; i >= 0; i--) {
          final m = DateTime(now.year, now.month - i);
          final key = _monthKey(m);
          monthlyBuckets[key] = {'received': 0, 'outstanding': 0};
        }

        for (final doc in paymentsSnap.docs) {
          final d = doc.data();
          final amount = (d['amount'] ?? 0).toDouble();
          final type = (d['type'] ?? '').toString();
          final status = (d['status'] ?? '').toString();
          final dueDate =
              (d['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now();
          final paidAt = (d['paidAt'] as Timestamp?)?.toDate();

          final isCompleted = status == 'PaymentStatus.completed';
          final isPending = status == 'PaymentStatus.pending';

          // Date filter: for completed payments use paidAt, otherwise dueDate
          final filterDate = (isCompleted && paidAt != null) ? paidAt : dueDate;
          final inRange = filter == DashboardFilter.all ||
              (!filterDate.isBefore(range.start) &&
                  !filterDate.isAfter(range.end));

          if (inRange) {
            if (type.contains('hostelFee')) {
              if (isCompleted) hostelReceived += amount;
              if (isPending) hostelOutstanding += amount;
            } else if (type.contains('gymFee')) {
              if (isCompleted) gymReceived += amount;
              if (isPending) gymOutstanding += amount;
            } else if (type.contains('messFee')) {
              if (isCompleted) messReceived += amount;
              if (isPending) messOutstanding += amount;
            }
          }

          // Monthly trend: always aggregate last 6 months regardless of filter
          if (isCompleted && paidAt != null) {
            final key = _monthKey(paidAt);
            if (monthlyBuckets.containsKey(key)) {
              monthlyBuckets[key]!['received'] =
                  (monthlyBuckets[key]!['received'] ?? 0) + amount;
            }
          } else if (isPending) {
            final key = _monthKey(dueDate);
            if (monthlyBuckets.containsKey(key)) {
              monthlyBuckets[key]!['outstanding'] =
                  (monthlyBuckets[key]!['outstanding'] ?? 0) + amount;
            }
          }

          recentPayments.add({...d, 'id': doc.id});
        }

        recentPayments.sort((a, b) {
          final aDate =
              (a['dueDate'] as Timestamp?)?.toDate() ?? DateTime(2020);
          final bDate =
              (b['dueDate'] as Timestamp?)?.toDate() ?? DateTime(2020);
          return bDate.compareTo(aDate);
        });

        final monthlyRevenue = monthlyBuckets.entries.map((e) {
          return MonthlyRevenue(
            month: e.key,
            received: e.value['received'] ?? 0,
            outstanding: e.value['outstanding'] ?? 0,
          );
        }).toList();

        // ── Applications aggregation ──────────────────────────────────────
        int appTotal = 0, appPending = 0, appApproved = 0, appRejected = 0;
        // Residents reflect CURRENT room assignments, independent of the
        // selected date filter.
        int residentsAll = 0;
        final recentApps = <Map<String, dynamic>>[];

        // Monthly application buckets for last 6 months
        final appMonthlyBuckets = <String, Map<String, int>>{};
        for (int i = 5; i >= 0; i--) {
          final m = DateTime(now.year, now.month - i);
          final key = _monthKey(m);
          appMonthlyBuckets[key] = {
            'total': 0,
            'approved': 0,
            'pending': 0,
            'rejected': 0,
          };
        }

        for (final doc in appsSnap.docs) {
          final d = doc.data();
          final createdAt =
              (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

          final inRange = filter == DashboardFilter.all ||
              (!createdAt.isBefore(range.start) &&
                  !createdAt.isAfter(range.end));

          final docStatus = (d['status'] ?? '').toString();
          if (docStatus == 'room_assigned') residentsAll++;

          if (inRange) {
            appTotal++;
            if (docStatus == 'pending') {
              appPending++;
            } else if (docStatus == 'approved' ||
                docStatus == 'room_assigned' ||
                docStatus == 'fee_confirmed' ||
                docStatus == 'fee_challan_generated') {
              appApproved++;
            } else if (docStatus == 'rejected') {
              appRejected++;
            }
          }

          // Monthly application trend
          final mKey = _monthKey(createdAt);
          if (appMonthlyBuckets.containsKey(mKey)) {
            appMonthlyBuckets[mKey]!['total'] =
                (appMonthlyBuckets[mKey]!['total'] ?? 0) + 1;
            if (docStatus == 'pending') {
              appMonthlyBuckets[mKey]!['pending'] =
                  (appMonthlyBuckets[mKey]!['pending'] ?? 0) + 1;
            } else if (docStatus == 'approved' ||
                docStatus == 'room_assigned' ||
                docStatus == 'fee_confirmed' ||
                docStatus == 'fee_challan_generated') {
              appMonthlyBuckets[mKey]!['approved'] =
                  (appMonthlyBuckets[mKey]!['approved'] ?? 0) + 1;
            } else if (docStatus == 'rejected') {
              appMonthlyBuckets[mKey]!['rejected'] =
                  (appMonthlyBuckets[mKey]!['rejected'] ?? 0) + 1;
            }
          }

          recentApps.add({...d, 'id': doc.id});
        }

        recentApps.sort((a, b) {
          final aDate =
              (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2020);
          final bDate =
              (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2020);
          return bDate.compareTo(aDate);
        });

        final monthlyApplications = appMonthlyBuckets.entries.map((e) {
          return MonthlyApplicationCount(
            month: e.key,
            total: e.value['total'] ?? 0,
            approved: e.value['approved'] ?? 0,
            pending: e.value['pending'] ?? 0,
            rejected: e.value['rejected'] ?? 0,
          );
        }).toList();

        // ── Student stats ─────────────────────────────────────────────────
        int totalStudents = 0, activeStudents = 0;
        for (final doc in profilesSnap.docs) {
          final d = doc.data();
          totalStudents++;
          if ((d['status'] ?? '') == 'active') activeStudents++;
        }

        // ── Gym stats ─────────────────────────────────────────────────────
        int gymMembers = 0;
        final recentGym = <Map<String, dynamic>>[];
        for (final doc in gymSnap.docs) {
          final d = doc.data();
          if ((d['status'] ?? '') == 'active') gymMembers++;
          recentGym.add({...d, 'id': doc.id});
        }
        recentGym.sort((a, b) {
          final aDate =
              (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2020);
          final bDate =
              (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2020);
          return bDate.compareTo(aDate);
        });

        // ── Mess bills ────────────────────────────────────────────────────
        double messBillsOutstanding = 0;
        int studentsWithDues = 0;
        final recentMessBills = <Map<String, dynamic>>[];
        for (final doc in messBillsSnap.docs) {
          final d = doc.data();
          final amount = (d['amount'] ?? 0).toDouble();
          final status = (d['status'] ?? 'unpaid').toString();
          if (status == 'unpaid' && amount > 0) {
            messBillsOutstanding += amount;
            studentsWithDues++;
          }
          recentMessBills.add({...d, 'id': doc.id});
        }
        recentMessBills.sort((a, b) {
          final aDate =
              (a['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime(2020);
          final bDate =
              (b['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime(2020);
          return bDate.compareTo(aDate);
        });

        return DashboardData(
          financial: FinancialSummary(
            hostelFeesReceived: hostelReceived,
            hostelFeesOutstanding: hostelOutstanding,
            gymFeesReceived: gymReceived,
            gymFeesOutstanding: gymOutstanding,
            messFeesReceived: messReceived,
            // Outstanding mess = unpaid bills only. Pending messFee payment
            // records represent the SAME debt awaiting verification — adding
            // them would double count.
            messFeesOutstanding: messBillsOutstanding,
          ),
          applications: ApplicationStats(
            total: appTotal,
            pending: appPending,
            approved: appApproved,
            rejected: appRejected,
          ),
          students: StudentStats(
            total: totalStudents,
            active: activeStudents,
            hostelResidents: residentsAll,
            gymMembers: gymMembers,
            withOutstandingDues: studentsWithDues,
          ),
          monthlyRevenue: monthlyRevenue,
          monthlyApplications: monthlyApplications,
          recentApplications: recentApps.take(5).toList(),
          recentGymRegistrations: recentGym.take(5).toList(),
          recentPayments: recentPayments.take(5).toList(),
          recentMessBills: recentMessBills.take(5).toList(),
        );
      },
    );
  }

  String _monthKey(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}
