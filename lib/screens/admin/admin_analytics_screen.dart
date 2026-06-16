import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../services/dashboard_service.dart';
import '../../widgets/ui_kit.dart';

// ── Filter state ─────────────────────────────────────────────────────────────

final _filterProvider =
    StateProvider<DashboardFilter>((ref) => DashboardFilter.all);
final _customRangeProvider =
    StateProvider<DashboardDateRange?>((ref) => null);

// ── Root screen ───────────────────────────────────────────────────────────────

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Analytics')),
      body: const _AnalyticsBody(),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _AnalyticsBody extends ConsumerStatefulWidget {
  const _AnalyticsBody();

  @override
  ConsumerState<_AnalyticsBody> createState() => _AnalyticsBodyState();
}

class _AnalyticsBodyState extends ConsumerState<_AnalyticsBody> {
  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(_filterProvider);
    final customRange = ref.watch(_customRangeProvider);
    final service = ref.read(dashboardServiceProvider);

    return StreamBuilder<DashboardData>(
      stream:
          service.getDashboardStream(filter: filter, customRange: customRange),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting && data == null;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter bar
              _FilterBar(
                selected: filter,
                onSelected: (f) async {
                  if (f == DashboardFilter.custom) {
                    await _pickRange(context, ref);
                  } else {
                    ref.read(_filterProvider.notifier).state = f;
                  }
                },
              ),
              const SizedBox(height: 20),

              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                if (snapshot.hasError ||
                    (data == null && snapshot.connectionState !=
                        ConnectionState.waiting))
                  _PermissionWarning(
                      error: snapshot.error?.toString() ?? 'No data'),

                // ── Financial Overview ──────────────────────────────────
                _SectionHeader('Financial Overview'),
                const SizedBox(height: 12),
                _FinancialOverviewGrid(data?.financial),
                const SizedBox(height: 12),
                _CollectionRateCard(data?.financial),
                const SizedBox(height: 24),

                // ── Application Statistics ──────────────────────────────
                _SectionHeader('Application Statistics'),
                const SizedBox(height: 12),
                _ApplicationStatsRow(data?.applications),
                const SizedBox(height: 24),

                // ── Student Statistics ──────────────────────────────────
                _SectionHeader('Student Statistics'),
                const SizedBox(height: 12),
                _StudentStatsGrid(data?.students),
                const SizedBox(height: 24),

                // ── Charts ──────────────────────────────────────────────
                _SectionHeader('Charts & Analytics'),
                const SizedBox(height: 12),
                _ChartsSection(data),
                const SizedBox(height: 24),

                // ── Recent Activities ───────────────────────────────────
                _SectionHeader('Recent Activities'),
                const SizedBox(height: 12),
                _RecentActivitiesSection(data),
                const SizedBox(height: 32),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ref.read(_customRangeProvider.notifier).state = DashboardDateRange(
        start: picked.start,
        end: picked.end,
      );
      ref.read(_filterProvider.notifier).state = DashboardFilter.custom;
    }
  }
}

// ── Filter Bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});
  final DashboardFilter selected;
  final ValueChanged<DashboardFilter> onSelected;

  static const _labels = {
    DashboardFilter.today: 'Today',
    DashboardFilter.thisWeek: 'This Week',
    DashboardFilter.thisMonth: 'This Month',
    DashboardFilter.thisYear: 'This Year',
    DashboardFilter.custom: 'Custom',
    DashboardFilter.all: 'All Time',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: DashboardFilter.values.map((f) {
          final isSelected = selected == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_labels[f] ?? f.name),
              selected: isSelected,
              onSelected: (_) => onSelected(f),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

// ── Permission Warning ────────────────────────────────────────────────────────

class _PermissionWarning extends StatelessWidget {
  const _PermissionWarning({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    final isPermission = error.contains('permission-denied') ||
        error.contains('insufficient permissions');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPermission
                  ? 'Firestore rules need updating. Go to Firebase Console → Firestore → Rules and allow authenticated reads.'
                  : error,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Financial Overview ────────────────────────────────────────────────────────

class _FinancialOverviewGrid extends StatelessWidget {
  const _FinancialOverviewGrid(this.financial);
  final FinancialSummary? financial;

  @override
  Widget build(BuildContext context) {
    final f = financial;
    final fmt = NumberFormat('#,##0', 'en_US');

    final cards = [
      _FinCard('Hostel Received',
          'PKR ${fmt.format(f?.hostelFeesReceived ?? 0)}',
          Icons.home_work_rounded, AppColors.success, true),
      _FinCard('Hostel Outstanding',
          'PKR ${fmt.format(f?.hostelFeesOutstanding ?? 0)}',
          Icons.home_work_outlined, AppColors.error, false),
      _FinCard('Gym Received',
          'PKR ${fmt.format(f?.gymFeesReceived ?? 0)}',
          Icons.fitness_center_rounded, AppColors.success, true),
      _FinCard('Gym Outstanding',
          'PKR ${fmt.format(f?.gymFeesOutstanding ?? 0)}',
          Icons.fitness_center_outlined, AppColors.error, false),
      _FinCard('Mess Received',
          'PKR ${fmt.format(f?.messFeesReceived ?? 0)}',
          Icons.restaurant_rounded, AppColors.success, true),
      _FinCard('Mess Outstanding',
          'PKR ${fmt.format(f?.messFeesOutstanding ?? 0)}',
          Icons.restaurant_outlined, AppColors.error, false),
      _FinCard('Total Revenue',
          'PKR ${fmt.format(f?.totalReceived ?? 0)}',
          Icons.account_balance_rounded, AppColors.primary, true,
          highlight: true),
      _FinCard('Total Outstanding',
          'PKR ${fmt.format(f?.totalOutstanding ?? 0)}',
          Icons.warning_amber_rounded, const Color(0xFFDC2626), false,
          highlight: true),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 600 ? 4 : 2;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: constraints.maxWidth > 600 ? 1.5 : 1.3,
        children: cards,
      );
    });
  }
}

class _FinCard extends StatelessWidget {
  const _FinCard(this.title, this.value, this.icon, this.color, this.received,
      {this.highlight = false});
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool received;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: highlight ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: color.withValues(alpha: highlight ? 0.4 : 0.2),
            width: highlight ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (received ? AppColors.success : AppColors.error)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  received ? 'Received' : 'Due',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: received ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(title,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary),
              maxLines: 2),
        ],
      ),
    );
  }
}

// ── Collection Rate ───────────────────────────────────────────────────────────
// Animated progress panel: overall collection percentage plus a per-module
// breakdown (hostel / gym / mess), each bar easing to its value on load.

class _CollectionRateCard extends StatelessWidget {
  const _CollectionRateCard(this.financial);
  final FinancialSummary? financial;

  @override
  Widget build(BuildContext context) {
    final f = financial;
    final received = f?.totalReceived ?? 0;
    final outstanding = f?.totalOutstanding ?? 0;
    final total = received + outstanding;
    if (total <= 0) return const SizedBox.shrink();

    final overall = received / total;

    double rate(double r, double o) => (r + o) <= 0 ? 0 : r / (r + o);
    final rows = [
      ('Hostel', rate(f!.hostelFeesReceived, f.hostelFeesOutstanding),
          AppColors.primary),
      ('Gym', rate(f.gymFeesReceived, f.gymFeesOutstanding),
          const Color(0xFF7C3AED)),
      ('Mess', rate(f.messFeesReceived, f.messFeesOutstanding),
          AppColors.success),
    ];

    return HoverLiftCard(
      padding: const EdgeInsets.all(20),
      border: Border.all(color: AppColors.divider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_up_rounded,
                    color: AppColors.success, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Collection Rate',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ),
              AnimatedCount(
                value: overall * 100,
                suffix: '%',
                useGrouping: false,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Overall animated bar
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: overall),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: AppColors.divider,
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.success),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Per-module rates
          for (final r in rows) ...[
            Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(r.$1,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: r.$2),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 7,
                        backgroundColor: AppColors.divider,
                        valueColor: AlwaysStoppedAnimation(r.$3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${(r.$2 * 100).toStringAsFixed(0)}%',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: r.$3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ── Application Stats ─────────────────────────────────────────────────────────

class _ApplicationStatsRow extends StatelessWidget {
  const _ApplicationStatsRow(this.apps);
  final ApplicationStats? apps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _StatBox('Total', '${apps?.total ?? 0}',
                Icons.list_alt_rounded, AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatBox('Approved', '${apps?.approved ?? 0}',
                Icons.check_circle_outline_rounded, AppColors.success)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatBox('Pending', '${apps?.pending ?? 0}',
                Icons.pending_actions_rounded, AppColors.warning)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatBox('Rejected', '${apps?.rejected ?? 0}',
                Icons.cancel_outlined, AppColors.error)),
      ],
    );
  }
}

// ── Student Stats ─────────────────────────────────────────────────────────────

class _StudentStatsGrid extends StatelessWidget {
  const _StudentStatsGrid(this.students);
  final StudentStats? students;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 600 ? 5 : 3;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
        children: [
          _StatBox('Total Students', '${students?.total ?? 0}',
              Icons.school_rounded, AppColors.primary),
          _StatBox('Active', '${students?.active ?? 0}',
              Icons.person_rounded, AppColors.success),
          _StatBox('Residents', '${students?.hostelResidents ?? 0}',
              Icons.home_rounded, AppColors.info),
          _StatBox('Gym Members', '${students?.gymMembers ?? 0}',
              Icons.fitness_center_rounded, const Color(0xFF7C3AED)),
          _StatBox('With Dues', '${students?.withOutstandingDues ?? 0}',
              Icons.receipt_long_rounded, AppColors.error),
        ],
      );
    });
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox(this.title, this.value, this.icon, this.color);
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final numeric = double.tryParse(value);
    final valueStyle = TextStyle(
        fontSize: 20, fontWeight: FontWeight.w800, color: color);

    return HoverLiftCard(
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.2)),
      hoverBorderColor: color.withValues(alpha: 0.55),
      borderRadius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          numeric != null
              ? AnimatedCount(value: numeric, style: valueStyle)
              : Text(value, style: valueStyle),
          const SizedBox(height: 4),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
              maxLines: 2),
        ],
      ),
    );
  }
}

// ── Charts Section ────────────────────────────────────────────────────────────

class _ChartsSection extends StatelessWidget {
  const _ChartsSection(this.data);
  final DashboardData? data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(builder: (ctx, c) {
          final wide = c.maxWidth > 600;
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _RevenueBreakdownChart(data?.financial)),
                  const SizedBox(width: 12),
                  Expanded(
                      child:
                          _ReceivedVsOutstandingChart(data?.financial)),
                ])
              : Column(children: [
                  _RevenueBreakdownChart(data?.financial),
                  const SizedBox(height: 12),
                  _ReceivedVsOutstandingChart(data?.financial),
                ]);
        }),
        const SizedBox(height: 12),
        _MonthlyTrendChart(data?.monthlyRevenue),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (ctx, c) {
          final wide = c.maxWidth > 600;
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: _AppStatusPieChart(data?.applications)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _MonthlyAppBarChart(
                          data?.monthlyApplications)),
                ])
              : Column(children: [
                  _AppStatusPieChart(data?.applications),
                  const SizedBox(height: 12),
                  _MonthlyAppBarChart(data?.monthlyApplications),
                ]);
        }),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (ctx, c) {
          final wide = c.maxWidth > 600;
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _OccupancyChart(data?.students)),
                  const SizedBox(width: 12),
                  Expanded(child: _PaymentStatusChart(data?.financial)),
                ])
              : Column(children: [
                  _OccupancyChart(data?.students),
                  const SizedBox(height: 12),
                  _PaymentStatusChart(data?.financial),
                ]);
        }),
      ],
    );
  }
}

// ── Revenue Breakdown Pie ─────────────────────────────────────────────────────

class _RevenueBreakdownChart extends StatelessWidget {
  const _RevenueBreakdownChart(this.financial);
  final FinancialSummary? financial;

  @override
  Widget build(BuildContext context) {
    final hostel = financial?.hostelFeesReceived ?? 0;
    final gym = financial?.gymFeesReceived ?? 0;
    final mess = financial?.messFeesReceived ?? 0;
    final total = hostel + gym + mess;

    return _ChartCard(
      title: 'Revenue Breakdown',
      child: total == 0
          ? _EmptyChart('No revenue data')
          : Column(children: [
              SizedBox(
                height: 180,
                child: PieChart(PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 38,
                  sections: [
                    if (hostel > 0)
                      _pct(hostel, total, AppColors.primary),
                    if (gym > 0)
                      _pct(gym, total, const Color(0xFF7C3AED)),
                    if (mess > 0)
                      _pct(mess, total, AppColors.success),
                  ],
                )),
              ),
              const SizedBox(height: 12),
              const Wrap(spacing: 12, children: [
                _Leg(color: AppColors.primary, label: 'Hostel'),
                _Leg(color: Color(0xFF7C3AED), label: 'Gym'),
                _Leg(color: AppColors.success, label: 'Mess'),
              ]),
            ]),
    );
  }

  PieChartSectionData _pct(double v, double total, Color color) =>
      PieChartSectionData(
        color: color,
        value: v,
        title: '${(v / total * 100).toStringAsFixed(0)}%',
        radius: 50,
        titleStyle: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
}

// ── Received vs Outstanding Bar ───────────────────────────────────────────────

class _ReceivedVsOutstandingChart extends StatelessWidget {
  const _ReceivedVsOutstandingChart(this.financial);
  final FinancialSummary? financial;

  @override
  Widget build(BuildContext context) {
    final f = financial;
    const labels = ['Hostel', 'Gym', 'Mess'];
    final received = [
      f?.hostelFeesReceived ?? 0,
      f?.gymFeesReceived ?? 0,
      f?.messFeesReceived ?? 0
    ];
    final outstanding = [
      f?.hostelFeesOutstanding ?? 0,
      f?.gymFeesOutstanding ?? 0,
      f?.messFeesOutstanding ?? 0
    ];
    final maxY = [...received, ...outstanding]
        .fold<double>(0, (m, v) => v > m ? v : m);

    return _ChartCard(
      title: 'Received vs Outstanding',
      child: maxY == 0
          ? _EmptyChart('No payment data')
          : Column(children: [
              SizedBox(
                height: 180,
                child: BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < labels.length) {
                            return Text(labels[i],
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(
                    labels.length,
                    (i) => BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                          toY: received[i],
                          color: AppColors.success,
                          width: 10,
                          borderRadius: BorderRadius.circular(4)),
                      BarChartRodData(
                          toY: outstanding[i],
                          color: AppColors.error.withValues(alpha: 0.7),
                          width: 10,
                          borderRadius: BorderRadius.circular(4)),
                    ]),
                  ),
                )),
              ),
              const SizedBox(height: 8),
              const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Leg(color: AppColors.success, label: 'Received'),
                    SizedBox(width: 16),
                    _Leg(color: AppColors.error, label: 'Outstanding'),
                  ]),
            ]),
    );
  }
}

// ── Monthly Revenue Trend Line ────────────────────────────────────────────────

class _MonthlyTrendChart extends StatelessWidget {
  const _MonthlyTrendChart(this.months);
  final List<MonthlyRevenue>? months;

  @override
  Widget build(BuildContext context) {
    final data = months ?? [];
    final maxY = data.fold<double>(
        0,
        (m, r) => r.received > m
            ? r.received
            : r.outstanding > m
                ? r.outstanding
                : m);

    return _ChartCard(
      title: 'Monthly Revenue Trend (Last 6 Months)',
      child: data.isEmpty || maxY == 0
          ? _EmptyChart('No monthly data')
          : Column(children: [
              SizedBox(
                height: 200,
                child: LineChart(LineChartData(
                  minY: 0,
                  maxY: maxY * 1.2,
                  lineTouchData: const LineTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i >= 0 && i < data.length) {
                            return Text(data[i].month.split(' ')[0],
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary));
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: AppColors.divider, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(data.length,
                          (i) => FlSpot(i.toDouble(), data[i].received)),
                      isCurved: true,
                      color: AppColors.success,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.success.withValues(alpha: 0.1)),
                    ),
                    LineChartBarData(
                      spots: List.generate(data.length,
                          (i) => FlSpot(i.toDouble(), data[i].outstanding)),
                      isCurved: true,
                      color: AppColors.error,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.error.withValues(alpha: 0.08)),
                    ),
                  ],
                )),
              ),
              const SizedBox(height: 8),
              const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Leg(color: AppColors.success, label: 'Revenue'),
                    SizedBox(width: 16),
                    _Leg(color: AppColors.error, label: 'Outstanding'),
                  ]),
            ]),
    );
  }
}

// ── Application Status Pie ────────────────────────────────────────────────────

class _AppStatusPieChart extends StatelessWidget {
  const _AppStatusPieChart(this.apps);
  final ApplicationStats? apps;

  @override
  Widget build(BuildContext context) {
    final total = apps?.total ?? 0;
    final pending = apps?.pending ?? 0;
    final approved = apps?.approved ?? 0;
    final rejected = apps?.rejected ?? 0;

    return _ChartCard(
      title: 'Application Status',
      child: total == 0
          ? _EmptyChart('No applications')
          : Column(children: [
              SizedBox(
                height: 180,
                child: PieChart(PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 38,
                  sections: [
                    if (pending > 0)
                      PieChartSectionData(
                          color: AppColors.warning,
                          value: pending.toDouble(),
                          title: '$pending',
                          radius: 50,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    if (approved > 0)
                      PieChartSectionData(
                          color: AppColors.success,
                          value: approved.toDouble(),
                          title: '$approved',
                          radius: 50,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    if (rejected > 0)
                      PieChartSectionData(
                          color: AppColors.error,
                          value: rejected.toDouble(),
                          title: '$rejected',
                          radius: 50,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                  ],
                )),
              ),
              const SizedBox(height: 12),
              const Wrap(spacing: 12, children: [
                _Leg(color: AppColors.warning, label: 'Pending'),
                _Leg(color: AppColors.success, label: 'Approved'),
                _Leg(color: AppColors.error, label: 'Rejected'),
              ]),
            ]),
    );
  }
}

// ── Monthly Application Bar ───────────────────────────────────────────────────

class _MonthlyAppBarChart extends StatelessWidget {
  const _MonthlyAppBarChart(this.monthly);
  final List<MonthlyApplicationCount>? monthly;

  @override
  Widget build(BuildContext context) {
    final data = monthly ?? [];
    final maxY =
        data.fold<int>(0, (m, r) => r.total > m ? r.total : m);

    return _ChartCard(
      title: 'Monthly Applications',
      child: data.isEmpty || maxY == 0
          ? _EmptyChart('No application data')
          : SizedBox(
              height: 180,
              child: BarChart(BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.3,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i >= 0 && i < data.length) {
                          return Text(data[i].month.split(' ')[0],
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  data.length,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                          toY: data[i].total.toDouble(),
                          color: AppColors.primary.withValues(alpha: 0.7),
                          width: 14,
                          borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                ),
              )),
            ),
    );
  }
}

// ── Occupancy Pie ─────────────────────────────────────────────────────────────

class _OccupancyChart extends StatelessWidget {
  const _OccupancyChart(this.students);
  final StudentStats? students;

  @override
  Widget build(BuildContext context) {
    final total = students?.total ?? 0;
    final residents = students?.hostelResidents ?? 0;
    final others = total > residents ? total - residents : 0;

    return _ChartCard(
      title: 'Hostel Occupancy',
      child: total == 0
          ? _EmptyChart('No student data')
          : Column(children: [
              SizedBox(
                height: 180,
                child: PieChart(PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 38,
                  sections: [
                    if (residents > 0)
                      PieChartSectionData(
                          color: AppColors.primary,
                          value: residents.toDouble(),
                          title: '$residents',
                          radius: 50,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    if (others > 0)
                      PieChartSectionData(
                          color: AppColors.divider,
                          value: others.toDouble(),
                          title: '$others',
                          radius: 50,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary)),
                  ],
                )),
              ),
              const SizedBox(height: 12),
              const Wrap(spacing: 12, children: [
                _Leg(color: AppColors.primary, label: 'Residents'),
                _Leg(color: AppColors.divider, label: 'Others'),
              ]),
            ]),
    );
  }
}

// ── Payment Status Pie ────────────────────────────────────────────────────────

class _PaymentStatusChart extends StatelessWidget {
  const _PaymentStatusChart(this.financial);
  final FinancialSummary? financial;

  @override
  Widget build(BuildContext context) {
    final received = financial?.totalReceived ?? 0;
    final outstanding = financial?.totalOutstanding ?? 0;
    final total = received + outstanding;

    return _ChartCard(
      title: 'Payment Status',
      child: total == 0
          ? _EmptyChart('No payment data')
          : Column(children: [
              SizedBox(
                height: 180,
                child: PieChart(PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 38,
                  sections: [
                    if (received > 0)
                      PieChartSectionData(
                          color: AppColors.success,
                          value: received,
                          title:
                              '${(received / total * 100).toStringAsFixed(0)}%',
                          radius: 50,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    if (outstanding > 0)
                      PieChartSectionData(
                          color: AppColors.error,
                          value: outstanding,
                          title:
                              '${(outstanding / total * 100).toStringAsFixed(0)}%',
                          radius: 50,
                          titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                  ],
                )),
              ),
              const SizedBox(height: 12),
              const Wrap(spacing: 12, children: [
                _Leg(color: AppColors.success, label: 'Collected'),
                _Leg(color: AppColors.error, label: 'Outstanding'),
              ]),
            ]),
    );
  }
}

// ── Recent Activities ─────────────────────────────────────────────────────────

class _RecentActivitiesSection extends StatefulWidget {
  const _RecentActivitiesSection(this.data);
  final DashboardData? data;

  @override
  State<_RecentActivitiesSection> createState() =>
      _RecentActivitiesSectionState();
}

class _RecentActivitiesSectionState extends State<_RecentActivitiesSection>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          TabBar(
            controller: _tab,
            labelStyle:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'Applications'),
              Tab(text: 'Gym'),
              Tab(text: 'Payments'),
              Tab(text: 'Mess Bills'),
            ],
          ),
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tab,
              children: [
                _ActivityList(
                  items: widget.data?.recentApplications ?? [],
                  icon: Icons.assignment_rounded,
                  color: AppColors.primary,
                  titleKey: 'studentName',
                  subtitleKey: 'status',
                  dateKey: 'createdAt',
                  subtitleFormatter: _fmtAppStatus,
                ),
                _ActivityList(
                  items: widget.data?.recentGymRegistrations ?? [],
                  icon: Icons.fitness_center_rounded,
                  color: const Color(0xFF7C3AED),
                  titleKey: 'studentName',
                  subtitleKey: 'status',
                  dateKey: 'createdAt',
                  subtitleFormatter: _capitalize,
                ),
                _ActivityList(
                  items: widget.data?.recentPayments ?? [],
                  icon: Icons.payments_rounded,
                  color: AppColors.success,
                  titleKey: 'description',
                  subtitleKey: 'type',
                  dateKey: 'dueDate',
                  amountKey: 'amount',
                  subtitleFormatter: _fmtType,
                ),
                _ActivityList(
                  items: widget.data?.recentMessBills ?? [],
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.info,
                  titleKey: 'studentName',
                  subtitleKey: 'status',
                  dateKey: 'lastUpdated',
                  amountKey: 'amount',
                  subtitleFormatter: _capitalize,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtAppStatus(String s) {
    const m = {
      'pending': 'Pending Review',
      'fee_challan_generated': 'Fee Challan Generated',
      'fee_confirmed': 'Fee Confirmed',
      'room_assigned': 'Room Assigned',
      'rejected': 'Rejected',
    };
    return m[s] ?? _capitalize(s);
  }

  String _fmtType(String s) => s
      .replaceAll('PaymentType.', '')
      .replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(0)}');

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({
    required this.items,
    required this.icon,
    required this.color,
    required this.titleKey,
    required this.subtitleKey,
    required this.dateKey,
    this.amountKey,
    required this.subtitleFormatter,
  });

  final List<Map<String, dynamic>> items;
  final IconData icon;
  final Color color;
  final String titleKey;
  final String subtitleKey;
  final String dateKey;
  final String? amountKey;
  final String Function(String) subtitleFormatter;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No recent activity',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 56, endIndent: 16),
      itemBuilder: (context, i) {
        final item = items[i];
        final title = (item[titleKey] ?? '—').toString();
        final subtitle =
            subtitleFormatter((item[subtitleKey] ?? '').toString());
        final dateRaw = item[dateKey];
        String dateStr = '';
        if (dateRaw is Timestamp) {
          dateStr = DateFormat('MMM dd, yy • h:mm a')
              .format(dateRaw.toDate());
        }
        final amountRaw =
            amountKey != null ? item[amountKey!] : null;
        final amountStr = amountRaw != null
            ? NumberFormat('#,##0', 'en_US').format(amountRaw)
            : null;

        return ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          title: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              if (dateStr.isNotEmpty)
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textDisabled)),
            ],
          ),
          trailing: amountStr != null
              ? Text('PKR $amountStr',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary))
              : null,
        );
      },
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_outlined,
                color: AppColors.textDisabled, size: 32),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(
                    color: AppColors.textDisabled, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Leg extends StatelessWidget {
  const _Leg({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
