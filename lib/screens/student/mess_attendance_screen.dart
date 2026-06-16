import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/mess_attendance_service.dart';
import '../../services/mess_service.dart';
import '../../models/mess_bill_model.dart';
import '../../models/payment_model.dart';
import '../../services/payment_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../platform_io.dart';
import '../../config/theme.dart';
import '../../config/app_keys.dart';

class MessAttendanceScreen extends ConsumerStatefulWidget {
  const MessAttendanceScreen({super.key});

  @override
  ConsumerState<MessAttendanceScreen> createState() =>
      _MessAttendanceScreenState();
}

class _MessAttendanceScreenState extends ConsumerState<MessAttendanceScreen>
    with SingleTickerProviderStateMixin {
  final DateTime _selectedDate = DateTime.now();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Attendance'),
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }
          return _buildBody(context, user.uid);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBody(BuildContext context, String userId) {
    return StreamBuilder<Map<String, dynamic>>(
      // Convert Future to Stream for UI consistency, or just use FutureBuilder.
      // Wait, let's use FutureBuilder since getStudentAttendanceStats is a Future.
      stream: Stream.fromFuture(ref
          .read(messAttendanceServiceProvider)
          .getStudentAttendanceStats(userId)),
      builder: (context, statsSnap) {
        final stats = statsSnap.data ?? {};
        final presentMeals = stats['presentMeals'] as int? ?? 0;
        final absentMeals = stats['absentMeals'] as int? ?? 0;
        final attendedDays = stats['attendedDays'] as int? ?? 0;
        final attendanceRate = (presentMeals + absentMeals) == 0
            ? 0.0
            : (presentMeals / (presentMeals + absentMeals)) * 100;

        // Fetch monthly records to power the calendar
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: ref
              .read(messAttendanceServiceProvider)
              .getStudentAttendance(userId),
          builder: (context, recordsSnap) {
            final records = recordsSnap.data ?? [];

            // Build a date → status map for the calendar
            final Map<String, bool> datePresenceMap = {};
            for (final r in records) {
              final ts = r['date'] as Timestamp?;
              if (ts != null) {
                final dateKey =
                    DateFormat('yyyy-MM-dd').format(ts.toDate());
                datePresenceMap[dateKey] =
                    (r['isPresent'] as bool?) ?? false;
              }
            }

            // Streak calculation
            int streak = 0;
            DateTime check = DateTime.now();
            while (true) {
              final key =
                  DateFormat('yyyy-MM-dd').format(check);
              if (datePresenceMap[key] == true) {
                streak++;
                check = check.subtract(const Duration(days: 1));
              } else {
                break;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header banner ──────────────────────────────────
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  
                  // ── Mess Bill Banner ───────────────────────────────
                  _buildMessBillCard(userId),
                  const SizedBox(height: 16),

                  // ── Streak counter ─────────────────────────────────
                  if (streak > 0) _buildStreakBanner(streak),
                  if (streak > 0) const SizedBox(height: 16),

                  // ── Monthly stats row ──────────────────────────────
                  _buildStatsRow(
                      context, presentMeals, absentMeals, attendanceRate),
                  const SizedBox(height: 24),

                  // ── Monthly calendar ───────────────────────────────
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedDate),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '● Present   ● Absent   ● Not marked',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  _buildMonthCalendar(context, datePresenceMap),
                  const SizedBox(height: 24),

                  // ── Upcoming 7-day attendance ─────────────────────
                  Text(
                    'Upcoming 7 Days',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mark your meal attendance for the next 7 days',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  _SevenDayMealCards(userId: userId),

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.restaurant_menu,
                color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mess Attendance',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessBillCard(String userId) {
    return StreamBuilder<MessBillModel?>(
      stream: ref.read(messServiceProvider).getStudentBill(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final bill = snapshot.data!;
        if (bill.amount <= 0) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      color: Colors.red, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Outstanding Mess Bill',
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Rs. ${bill.amount.toStringAsFixed(0)}',
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _payMessBill(bill),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Pay Bill',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _payMessBill(MessBillModel bill) async {
    // Show inline mess-payment bottom sheet (no hostel fee visible)
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MessPaymentSheet(
        bill: bill,
        paymentService: ref.read(paymentServiceProvider),
      ),
    );
  }

  Widget _buildStreakBanner(int streak) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning.withValues(alpha: 0.15),
            AppColors.accent.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              color: AppColors.warning, size: 26),
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$streak days ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.warning,
                  ),
                ),
                const TextSpan(
                  text: 'in a row! Keep it up!',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, int present, int absent,
      double rate) {
    return Row(
      children: [
        Expanded(
            child: _StatCell(
                label: 'Present', value: '$present', color: AppColors.success)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCell(
                label: 'Absent', value: '$absent', color: AppColors.error)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCell(
                label: 'Rate',
                value: '${rate.toStringAsFixed(0)}%',
                color: AppColors.info)),
      ],
    );
  }

  Widget _buildMonthCalendar(BuildContext context,
      Map<String, bool> datePresenceMap) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    // weekday: 1=Mon…7=Sun → offset for Sun-first grid
    final startOffset = (firstDay.weekday % 7); // 0=Sun, 1=Mon, ...

    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Day of week headers
          Row(
            children: weekdays
                .map((d) => Expanded(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Date grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startOffset) {
                return const SizedBox.shrink();
              }
              final day = index - startOffset + 1;
              final date = DateTime(now.year, now.month, day);
              final key = DateFormat('yyyy-MM-dd').format(date);
              final isToday = day == now.day;
              final isPresent = datePresenceMap[key];
              final isFuture = date.isAfter(now);

              Color dotColor;
              if (isFuture) {
                dotColor = Colors.transparent;
              } else if (isPresent == true) {
                dotColor = AppColors.success;
              } else if (isPresent == false) {
                dotColor = AppColors.error;
              } else {
                dotColor = AppColors.textDisabled;
              }

              Widget dayWidget = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isToday ? FontWeight.w800 : FontWeight.w400,
                      color: isToday
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (!isFuture)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              );

              // Today gets a pulsing ring
              if (isToday) {
                dayWidget = AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: dayWidget,
                );
              }

              return dayWidget;
            },
          ),

          // Legend
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.success, label: 'Present'),
              SizedBox(width: 16),
              _LegendDot(color: AppColors.error, label: 'Absent'),
              SizedBox(width: 16),
              _LegendDot(color: AppColors.textDisabled, label: 'Not marked'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Upcoming 7-day meal attendance (one card per day) ────────────────────────

class _SevenDayMealCards extends StatelessWidget {
  const _SevenDayMealCards({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return Column(
      children: List.generate(7, (i) {
        final date = DateTime(today.year, today.month, today.day + i);
        return _DayMealCard(userId: userId, date: date, isToday: i == 0);
      }),
    );
  }
}

class _DayMealCard extends ConsumerStatefulWidget {
  const _DayMealCard({
    required this.userId,
    required this.date,
    required this.isToday,
  });
  final String userId;
  final DateTime date;
  final bool isToday;

  @override
  ConsumerState<_DayMealCard> createState() => _DayMealCardState();
}

class _DayMealCardState extends ConsumerState<_DayMealCard> {
  final Map<String, bool?> _isPresent = {
    'breakfast': null,
    'lunch': null,
    'dinner': null,
  };
  final Map<String, bool> _isLocked = {
    'breakfast': false,
    'lunch': false,
    'dinner': false,
  };
  final Map<String, bool> _isLoading = {
    'breakfast': false,
    'lunch': false,
    'dinner': false,
  };
  bool _isInitialLoading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isToday; // auto-expand today
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final service = ref.read(messAttendanceServiceProvider);
      final futures = ['breakfast', 'lunch', 'dinner'].map((meal) async {
        final record = await service.getAttendanceStatus(
          studentId: widget.userId,
          date: widget.date,
          mealType: meal,
        );
        if (record != null && mounted) {
          _isPresent[meal] = record['isPresent'] as bool?;
          _isLocked[meal] = true;
        }
      });
      await Future.wait(futures);
      if (mounted) setState(() => _isInitialLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _markAttendance(String meal, bool isPresent) async {
    if (_isLocked[meal] == true) return;
    setState(() => _isLoading[meal] = true);
    final messenger = AppKeys.scaffoldMessengerKey.currentState;
    try {
      final service = ref.read(messAttendanceServiceProvider);
      final user = ref.read(currentUserProvider).value;
      await service.markAttendance(
        studentId: widget.userId,
        studentName: user?.name ?? 'Student',
        isPresent: isPresent,
        date: widget.date,
        mealType: meal,
      );
      if (mounted) {
        setState(() {
          _isPresent[meal] = isPresent;
          _isLocked[meal] = true;
          _isLoading[meal] = false;
        });
        messenger?.showSnackBar(SnackBar(
          content: Text(
              'Marked ${meal.toUpperCase()} as ${isPresent ? 'Present' : 'Absent'}'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading[meal] = false);
      messenger?.showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  // Count how many meals are marked for this day
  int get _markedCount =>
      _isPresent.values.where((v) => v != null).length;

  @override
  Widget build(BuildContext context) {
    final dayLabel = widget.isToday
        ? 'Today'
        : DateFormat('EEEE').format(widget.date);
    final dateStr = DateFormat('MMM d').format(widget.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isToday
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border,
          width: widget.isToday ? 1.5 : 1.0,
        ),
        boxShadow: widget.isToday
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          // ── Day header (tap to expand/collapse) ───────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.isToday
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 18,
                      color: widget.isToday
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              dayLabel,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: widget.isToday
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (widget.isToday) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'TODAY',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Meal marked indicator
                  if (!_isInitialLoading)
                    Text(
                      '$_markedCount/3 marked',
                      style: TextStyle(
                        fontSize: 11,
                        color: _markedCount == 3
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontWeight: _markedCount == 3
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable meal rows ──────────────────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _isInitialLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Column(
                      children: [
                        _buildMealRow('Breakfast', 'breakfast'),
                        const SizedBox(height: 8),
                        _buildMealRow('Lunch', 'lunch'),
                        const SizedBox(height: 8),
                        _buildMealRow('Dinner', 'dinner'),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildMealRow(String label, String key) {
    final locked = _isLocked[key] == true;
    final present = _isPresent[key];
    final loading = _isLoading[key] == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (loading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (locked && present != null)
            Row(
              children: [
                Icon(
                  present ? Icons.check_circle : Icons.cancel,
                  color: present ? AppColors.success : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  present ? 'Present' : 'Absent',
                  style: TextStyle(
                    color: present ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.lock_outline,
                    size: 14, color: AppColors.textSecondary),
              ],
            )
          else
            Row(
              children: [
                _ActionBtn(
                  label: 'Present',
                  color: AppColors.success,
                  icon: Icons.check,
                  onTap: () => _markAttendance(key, true),
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: 'Absent',
                  color: AppColors.error,
                  icon: Icons.close,
                  onTap: () => _markAttendance(key, false),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mess Payment Bottom Sheet ─────────────────────────────────────────────────

class _MessPaymentSheet extends ConsumerStatefulWidget {
  const _MessPaymentSheet({
    required this.bill,
    required this.paymentService,
  });
  final MessBillModel bill;
  final PaymentService paymentService;

  @override
  ConsumerState<_MessPaymentSheet> createState() => _MessPaymentSheetState();
}

class _MessPaymentSheetState extends ConsumerState<_MessPaymentSheet> {
  bool _generating = false;
  bool _uploading = false;
  String? _paymentId;
  String? _bankName;
  String? _accountNumber;
  String? _accountTitle;
  bool _uploaded = false;

  @override
  void initState() {
    super.initState();
    _generatePayment();
  }

  Future<void> _generatePayment() async {
    setState(() => _generating = true);
    try {
      final payment = PaymentModel(
        id: '',
        userId: widget.bill.studentId,
        amount: widget.bill.amount,
        type: PaymentType.messFee,
        status: PaymentStatus.pending,
        description:
            'Mess Bill Payment for ${DateFormat('MMMM yyyy').format(DateTime.now())}',
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );
      final id = await widget.paymentService.createPayment(payment);
      final doc = await FirebaseFirestore.instance
          .collection('payments')
          .doc(id)
          .get();
      final data = doc.data();
      if (mounted) {
        setState(() {
          _paymentId = id;
          _bankName = data?['bankName'] as String?;
          _accountNumber = data?['accountNumber'] as String?;
          _accountTitle = data?['accountTitle'] as String?;
          _generating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _uploadScreenshot() async {
    if (_paymentId == null) return;
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final controller = TextEditingController(text: widget.bill.amount.toStringAsFixed(0));
    final double? amountOverride = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the actual amount you have paid as shown on your screenshot.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Paid Amount (Rs.)',
                border: OutlineInputBorder(),
                prefixText: 'Rs. ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                Navigator.pop(context, val);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
              }
            },
            child: const Text('Confirm & Upload'),
          ),
        ],
      ),
    );
    
    if (amountOverride == null) return;

    setState(() => _uploading = true);
    try {
      Object file = kIsWeb ? picked : File(picked.path);
      await widget.paymentService.uploadFeeChallanProof(
        paymentId: _paymentId!,
        userId: widget.bill.studentId,
        applicationId: null,
        imageFile: file,
        paidAmount: amountOverride,
      );
      if (mounted) {
        setState(() {
          _uploaded = true;
          _uploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Screenshot uploaded! Awaiting admin approval.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.restaurant_menu,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pay Mess Bill',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Amount: Rs. ${widget.bill.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 24),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: _generating
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bank Details
                        if (_bankName != null || _accountNumber != null) ...[
                          const Text(
                            'Pay to this account:',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.20)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_bankName != null)
                                  _BankDetailRow(
                                      label: 'Bank', value: _bankName!),
                                if (_accountTitle != null) ...[
                                  const SizedBox(height: 6),
                                  _BankDetailRow(
                                      label: 'Account Title',
                                      value: _accountTitle!),
                                ],
                                if (_accountNumber != null) ...[
                                  const SizedBox(height: 6),
                                  _BankDetailRow(
                                      label: 'Account No',
                                      value: _accountNumber!),
                                ],
                                const SizedBox(height: 6),
                                _BankDetailRow(
                                  label: 'Amount',
                                  value:
                                      'Rs. ${widget.bill.amount.toStringAsFixed(0)}',
                                  highlight: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Upload section
                        const Text(
                          'Upload Payment Screenshot:',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'After paying, upload a screenshot of your transaction receipt.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),

                        if (_uploaded) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.green, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Screenshot uploaded! Admin will review and approve.',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (_uploading || _paymentId == null)
                                ? null
                                : _uploadScreenshot,
                            icon: _uploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Icon(Icons.upload_file),
                            label: Text(_uploading
                                ? 'Uploading...'
                                : _uploaded
                                    ? 'Upload Again'
                                    : 'Upload Screenshot'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankDetailRow extends StatelessWidget {
  const _BankDetailRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  highlight ? FontWeight.w800 : FontWeight.w600,
              color:
                  highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
