import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/hostel_service.dart';
import '../../services/gym_service.dart';
import '../../services/complaint_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/ui_kit.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/images/fast_logo-removebg-preview.png',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            const Text('FAST Hostel System'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/student/dashboard/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/student/dashboard/profile'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(currentUserProvider.notifier).signOut();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: currentUserAsync.when(
        data: (user) => user == null
            ? const Center(child: Text('No user data'))
            : _DashboardContent(user: user),
        loading: () => const _DashboardShimmer(),
        error: (error, _) => _DashboardError(
          message: error.toString(),
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }
}

// ── Shimmer loading skeleton ────────────────────────────────────────────────

class _DashboardShimmer extends StatelessWidget {
  const _DashboardShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceAlt,
      highlightColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(
                4,
                (_) => Expanded(
                  child: Container(
                    height: 72,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              3,
              (_) => Container(
                height: 70,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Main content ────────────────────────────────────────────────────────────

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed(
              [
                _DashboardHeader(user: user),
                const SizedBox(height: 16),
                _QuickStatChips(userId: user.uid),
                const SizedBox(height: 20),
                _AccommodationCta(userId: user.uid),
                const SizedBox(height: 24),
                const _SectionTitle('Main Modules'),
                const SizedBox(height: 12),
                _MainModulesGrid(user: user),
                const SizedBox(height: 24),
                const _ImportantInfoCard(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Header with time-based greeting ────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.user});

  final UserModel user;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -55,
            right: 70,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.home_work_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_greeting, ${user.name.split(' ').first}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome to FAST Hostel System',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ARN: ${user.arnRollNumber} • Year: ${user.year}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick-stat chips ────────────────────────────────────────────────────────

class _QuickStatChips extends ConsumerWidget {
  const _QuickStatChips({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder(
      stream: ref.read(hostelServiceProvider).getUserApplicationStream(userId),
      builder: (context, appSnap) {
        final appStatus = appSnap.data?.status ?? 'none';
        final roomLabel = appStatus == 'room_assigned'
            ? appSnap.data?.selectedRoomId ?? 'Assigned'
            : 'None';

        return StreamBuilder<Map<String, dynamic>?>(
          stream: ref.read(gymServiceProvider).getUserRegistration(userId),
          builder: (context, gymSnap) {
            final gymStatus = gymSnap.data?['status'] ?? 'Not Registered';
            
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: ref.read(complaintServiceProvider).getUserComplaints(userId),
              builder: (context, cmpSnap) {
                final openComplaints = (cmpSnap.data ?? [])
                    .where((c) => c['status'] != 'resolved')
                    .length;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _QuickChip(
                        icon: Icons.bed_outlined,
                        label: 'Room',
                        value: roomLabel,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      const _QuickChip(
                        icon: Icons.restaurant,
                        label: 'Mess',
                        value: 'Active',
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 10),
                      _QuickChip(
                        icon: Icons.fitness_center,
                        label: 'Gym',
                        value: _gymLabel(gymStatus as String),
                        color: _gymColor(gymStatus),
                      ),
                      const SizedBox(width: 10),
                      _QuickChip(
                        icon: Icons.chat_bubble_outline,
                        label: 'Issues',
                        value: openComplaints == 0 ? 'Clear' : '$openComplaints Open',
                        color: openComplaints == 0 ? AppColors.success : AppColors.warning,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _gymLabel(String status) {
    switch (status) {
      case 'active': return 'Active';
      case 'pending': return 'Pending';
      case 'rejected': return 'Rejected';
      default: return 'Not Reg.';
    }
  }

  Color _gymColor(String status) {
    switch (status) {
      case 'active': return AppColors.success;
      case 'pending': return AppColors.warning;
      case 'rejected': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section title ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

// ── Accommodation CTA / Status Card ────────────────────────────────────────

class _AccommodationCta extends ConsumerWidget {
  const _AccommodationCta({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder(
      stream: ref.read(hostelServiceProvider).getUserApplicationStream(userId),
      builder: (context, snapshot) {
        final app = snapshot.data;
        final hasAccommodation = app?.status == 'room_assigned';

        if (hasAccommodation) return const SizedBox.shrink();

        // If app exists, show a status tracker card
        if (app != null && app.status != 'rejected') {
          return _ApplicationStatusCard(status: app.status);
        }

        // No app — show CTA
        return GestureDetector(
          onTap: () => context.push('/student/dashboard/hostel-application'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_turned_in, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'Start Accommodation Request',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ApplicationStatusCard extends StatelessWidget {
  const _ApplicationStatusCard({required this.status});
  final String status;

  static const _steps = [
    'Applied',
    'Fee Generated',
    'Fee Confirmed',
    'Room Assigned',
  ];

  static const _stepStatuses = [
    'pending',
    'fee_challan_generated',
    'fee_confirmed',
    'room_assigned',
  ];

  int get _currentStep {
    final idx = _stepStatuses.indexOf(status);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Application Status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
              ),
              const Spacer(),
              StatusBadge(
                label: _steps[_currentStep],
                type: _currentStep == 3
                    ? StatusType.success
                    : _currentStep == 2
                        ? StatusType.success
                        : _currentStep == 1
                            ? StatusType.warning
                            : StatusType.info,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(_steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                // Connector line
                final stepIdx = i ~/ 2;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: stepIdx < _currentStep
                        ? AppColors.success
                        : AppColors.border,
                  ),
                );
              }
              final stepIdx = i ~/ 2;
              final isCompleted = stepIdx < _currentStep;
              final isCurrent = stepIdx == _currentStep;
              return Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.success
                          : isCurrent
                              ? AppColors.primary
                              : AppColors.border,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCompleted ? Icons.check : Icons.circle,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 60,
                    child: Text(
                      _steps[stepIdx],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        color: isCurrent || isCompleted
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Main modules grid ───────────────────────────────────────────────────────

class _MainModulesGrid extends ConsumerWidget {
  const _MainModulesGrid({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder(
      stream: ref.read(hostelServiceProvider).getUserApplicationStream(user.uid),
      builder: (context, snapshot) {
        final application = snapshot.data;
        final hasAccommodation = application?.status == 'room_assigned';
        final isApproved = ['approved', 'fee_confirmed',
                'fee_challan_generated', 'room_assigned']
            .contains(application?.status);

        if (application == null || !isApproved) {
          return _quickGrid(context, [
            const _ModuleItem(
              title: 'Hostel Accommodation',
              icon: Icons.home_work,
              color: AppColors.primary,
              route: '/student/dashboard/hostel-application',
            ),
          ]);
        }

        if (isApproved && !hasAccommodation) {
          return _quickGrid(context, [
            const _ModuleItem(
              title: 'Hostel Allotment',
              icon: Icons.home_work,
              color: AppColors.primary,
              route: '/student/dashboard/room-selection',
            ),
          ]);
        }

        return _quickGrid(context, [
          const _ModuleItem(
            title: 'Mess Schedule',
            icon: Icons.restaurant_menu,
            color: Color(0xFF7C3AED),
            route: '/student/dashboard/mess',
          ),
          const _ModuleItem(
            title: 'Mess Attendance',
            icon: Icons.restaurant,
            color: AppColors.success,
            route: '/student/dashboard/mess-attendance',
          ),
          const _ModuleItem(
            title: 'Gym Registration',
            icon: Icons.fitness_center,
            color: AppColors.error,
            route: '/student/dashboard/gym-registration',
          ),
          const _ModuleItem(
            title: 'Complaint Box',
            icon: Icons.feedback,
            color: AppColors.warning,
            route: '/student/dashboard/complaint-box',
          ),
          const _ModuleItem(
            title: 'Notice Board',
            icon: Icons.announcement,
            color: Color(0xFF0D9488),
            route: '/student/dashboard/notice-board',
          ),
          const _ModuleItem(
            title: 'Payments',
            icon: Icons.payment,
            color: Colors.blue,
            route: '/student/dashboard/payments',
          ),
          const _ModuleItem(
            title: 'My Profile',
            icon: Icons.person,
            color: AppColors.info,
            route: '/student/dashboard/profile',
          ),
        ]);
      },
    );
  }

  Widget _quickGrid(BuildContext context, List<_ModuleItem> modules) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 600 ? 4 : 3;
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
        children: [
          for (var i = 0; i < modules.length; i++)
            StaggeredEntry(
              index: i,
              baseDelayMs: 50,
              child: _ModuleCard(item: modules[i]),
            ),
        ],
      );
    });
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.item});
  final _ModuleItem item;

  @override
  Widget build(BuildContext context) {
    return HoverLiftCard(
      onTap: () => context.push(item.route),
      color: item.color.withValues(alpha: 0.07),
      border: Border.all(color: item.color.withValues(alpha: 0.20)),
      hoverBorderColor: item.color.withValues(alpha: 0.6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleItem {
  const _ModuleItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String route;
}

// ── Info card at bottom ─────────────────────────────────────────────────────

class _ImportantInfoCard extends StatelessWidget {
  const _ImportantInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.info, size: 20),
              SizedBox(width: 8),
              Text(
                'Important Information',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Applications are processed first-come, first-served\n'
            '• Review takes 3–5 business days\n'
            '• You will be notified via email about status updates\n'
            '• Contact admin for any queries',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Error state ─────────────────────────────────────────────────────────────

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Error loading dashboard',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
