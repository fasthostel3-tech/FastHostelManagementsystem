import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/hostel_service.dart';
import '../../../services/hall_floor_room_service.dart';
import '../../../models/hostel_model.dart'
    show HostelModel, HostelApplicationModel;
import '../../../models/hall_floor_room_model.dart'
    show FloorModel, RoomModel, HallModel;
import '../../../config/theme.dart';

class RoomSelectionScreen extends ConsumerStatefulWidget {
  const RoomSelectionScreen({super.key});

  @override
  ConsumerState<RoomSelectionScreen> createState() =>
      _RoomSelectionScreenState();
}

class _RoomSelectionScreenState extends ConsumerState<RoomSelectionScreen> {
  HostelModel? _selectedHostel;
  HallModel? _selectedHall;
  FloorModel? _selectedFloor;
  RoomModel? _selectedRoom;
  bool _isConfirming = false;

  // Current wizard step: 0=hostel, 1=hall, 2=floor, 3=room
  int get _step {
    if (_selectedHostel == null) return 0;
    if (_selectedHall == null) return 1;
    if (_selectedFloor == null) return 2;
    return 3;
  }

  void _goBack() {
    setState(() {
      if (_selectedFloor != null) {
        _selectedFloor = null;
        _selectedRoom = null;
      } else if (_selectedHall != null) {
        _selectedHall = null;
      } else if (_selectedHostel != null) {
        _selectedHostel = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Room'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _selectedRoom != null
          ? FloatingActionButton.extended(
              onPressed: _isConfirming ? null : _handleConfirm,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 6,
              icon: _isConfirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_rounded),
              label: Text(
                _isConfirming
                    ? 'Confirming...'
                    : 'Confirm Room ${_selectedRoom!.name}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            )
          : null,
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return StreamBuilder<HostelApplicationModel?>(
            stream: ref
                .watch(hostelServiceProvider)
                .getUserApplicationStream(user.uid),
            builder: (context, appSnap) {
              if (appSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final application = appSnap.data;

              if (application == null) {
                return _EmptyState(
                  icon: Icons.assignment_late_outlined,
                  message: 'No hostel application found',
                  subtitle:
                      'Please submit an application before selecting a room.',
                  action: ElevatedButton(
                    onPressed: () => context
                        .go('/student/dashboard/hostel-application'),
                    child: const Text('Apply Now'),
                  ),
                );
              }

              if (!application.feeConfirmed) {
                return _EmptyState(
                  icon: Icons.payment_outlined,
                  iconColor: AppColors.warning,
                  message: 'Payment Pending',
                  subtitle:
                      'Your fee must be accepted by the admin before you can select a room.',
                  action: ElevatedButton(
                    onPressed: () =>
                        context.go('/student/dashboard/payments'),
                    child: const Text('View Payments'),
                  ),
                );
              }

              final gender = user.gender.toString().split('.').last;

              return Column(
                children: [
                  // ── Breadcrumb ─────────────────────────────────────
                  _Breadcrumb(
                    hostel: _selectedHostel,
                    hall: _selectedHall,
                    floor: _selectedFloor,
                    room: _selectedRoom,
                  ),

                  // ── Step content ───────────────────────────────────
                  Expanded(
                    child: _buildStep(user.uid, gender),
                  ),
                ],
              );
            },
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => _EmptyState(
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          message: 'Error loading user data',
          subtitle: e.toString(),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(currentUserProvider),
            child: const Text('Retry'),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String userId, String gender) {
    switch (_step) {
      case 0:
        return _HostelStep(
          gender: gender,
          onSelect: (h) => setState(() => _selectedHostel = h),
        );
      case 1:
        return _HallStep(
          hostelId: _selectedHostel!.id,
          onSelect: (h) => setState(() => _selectedHall = h),
        );
      case 2:
        return _FloorStep(
          hallId: _selectedHall!.id,
          onSelect: (f) => setState(() => _selectedFloor = f),
        );
      case 3:
      default:
        return _RoomStep(
          floorId: _selectedFloor!.id,
          selectedRoomId: _selectedRoom?.id,
          onSelect: (r) => setState(() => _selectedRoom = r),
        );
    }
  }

  Future<void> _handleConfirm() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    final application =
        await ref.read(hostelServiceProvider).getUserApplication(user.uid);
    if (application == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application not found. Please contact admin.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    await _confirmSelection(application);
  }

  Future<void> _confirmSelection(
      HostelApplicationModel application) async {
    if (_selectedRoom == null) return;

    final room = _selectedRoom!;
    if (!room.isAvailable || room.occupied >= room.capacity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('This room is full. Please select a different room.'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _selectedRoom = null);
      return;
    }

    setState(() => _isConfirming = true);

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not found');

      await ref.read(hostelServiceProvider).createRoomRequest(
            applicationId: application.id,
            studentId: user.uid,
            roomId: room.id,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Room selection submitted for admin approval!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }
}

// ── Breadcrumb ────────────────────────────────────────────────────────────────

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb(
      {required this.hostel,
      required this.hall,
      required this.floor,
      required this.room});

  final HostelModel? hostel;
  final HallModel? hall;
  final FloorModel? floor;
  final RoomModel? room;

  @override
  Widget build(BuildContext context) {
    final crumbs = <String>['Hostel'];
    if (hostel != null) crumbs.add(hostel!.name);
    if (hall != null) crumbs.add(hall!.name);
    if (floor != null) crumbs.add(floor!.name);
    if (room != null) crumbs.add('Room ${room!.name}');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primary.withValues(alpha: 0.06),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < crumbs.length; i++) ...[
              if (i > 0)
                const Icon(Icons.chevron_right,
                    size: 16, color: AppColors.textSecondary),
              Text(
                crumbs[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i == crumbs.length - 1
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: i == crumbs.length - 1
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Step 1: Hostel ────────────────────────────────────────────────────────────

class _HostelStep extends ConsumerWidget {
  const _HostelStep({required this.gender, required this.onSelect});
  final String gender;
  final ValueChanged<HostelModel> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider).value;
    final year = user?.year ?? '';

    return StreamBuilder<List<HostelModel>>(
      stream: ref
          .read(hostelServiceProvider)
          .getHostelsForStudent(year, gender),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final error = snap.error?.toString() ?? '';
        if (error.isNotEmpty) {
          return _StepError(
            message: error.contains('permission')
                ? 'Permission denied. Please contact admin to update Firestore rules.'
                : 'Error loading hostels: $error',
          );
        }

        final hostels = snap.data ?? [];

        if (hostels.isEmpty) {
          return const _EmptyState(
            icon: Icons.home_work_outlined,
            message: 'No hostels available',
            subtitle:
                'No hostels found for your gender. Please contact admin.',
          );
        }

        return _StepList(
          title: 'Select Hostel',
          subtitle: 'Choose your preferred hostel',
          children: hostels
              .map((h) => _SelectionTile(
                    icon: Icons.home_work_rounded,
                    title: h.name,
                    subtitle: h.description.isNotEmpty
                        ? h.description
                        : '${h.gender.toUpperCase()} Hostel',
                    badge:
                        '${h.totalFloors} floor${h.totalFloors != 1 ? 's' : ''}',
                    onTap: () => onSelect(h),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ── Step 2: Hall ──────────────────────────────────────────────────────────────

class _HallStep extends ConsumerWidget {
  const _HallStep({required this.hostelId, required this.onSelect});
  final String hostelId;
  final ValueChanged<HallModel> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<HallModel>>(
      stream: ref
          .read(hallFloorRoomServiceProvider)
          .getHallsForHostel(hostelId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final error = snap.error?.toString() ?? '';
        if (error.isNotEmpty) {
          return _StepError(
            message: error.contains('permission')
                ? 'Permission denied reading halls. Update Firestore security rules.'
                : 'Error loading halls: $error',
          );
        }

        final halls = snap.data ?? [];

        if (halls.isEmpty) {
          return const _EmptyState(
            icon: Icons.meeting_room_outlined,
            message: 'No halls found',
            subtitle:
                'This hostel has no halls configured yet. Please contact admin.',
          );
        }

        return _StepList(
          title: 'Select Hall',
          subtitle: 'Choose a hall within this hostel',
          children: halls
              .map((h) => _SelectionTile(
                    icon: Icons.meeting_room_rounded,
                    title: h.name,
                    subtitle: h.description ?? 'Hall',
                    onTap: () => onSelect(h),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ── Step 3: Floor ─────────────────────────────────────────────────────────────

class _FloorStep extends ConsumerWidget {
  const _FloorStep({required this.hallId, required this.onSelect});
  final String hallId;
  final ValueChanged<FloorModel> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<FloorModel>>(
      stream: ref
          .read(hallFloorRoomServiceProvider)
          .getFloorsForHall(hallId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final error = snap.error?.toString() ?? '';
        if (error.isNotEmpty) {
          return _StepError(
            message: error.contains('permission')
                ? 'Permission denied reading floors. Update Firestore security rules.'
                : 'Error loading floors: $error',
          );
        }

        final floors = snap.data ?? [];

        if (floors.isEmpty) {
          return const _EmptyState(
            icon: Icons.layers_outlined,
            message: 'No floors found',
            subtitle:
                'This hall has no floors configured yet. Please contact admin.',
          );
        }

        final sorted = List<FloorModel>.from(floors)
          ..sort((a, b) => a.floorNumber.compareTo(b.floorNumber));

        return _StepList(
          title: 'Select Floor',
          subtitle: 'Choose which floor you prefer',
          children: sorted
              .map((f) => _SelectionTile(
                    icon: Icons.layers_rounded,
                    title: f.name,
                    subtitle: 'Floor ${f.floorNumber}',
                    onTap: () => onSelect(f),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ── Step 4: Room ──────────────────────────────────────────────────────────────

class _RoomStep extends ConsumerWidget {
  const _RoomStep({
    required this.floorId,
    required this.selectedRoomId,
    required this.onSelect,
  });
  final String floorId;
  final String? selectedRoomId;
  final ValueChanged<RoomModel> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<RoomModel>>(
      stream: ref
          .read(hallFloorRoomServiceProvider)
          .getRoomsForFloor(floorId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final error = snap.error?.toString() ?? '';
        if (error.isNotEmpty) {
          return _StepError(
            message: error.contains('permission')
                ? 'Permission denied reading rooms. Update Firestore security rules.'
                : 'Error loading rooms: $error',
          );
        }

        final rooms = snap.data ?? [];
        final available =
            rooms.where((r) => r.isAvailable && r.occupied < r.capacity).toList();

        if (rooms.isEmpty) {
          return const _EmptyState(
            icon: Icons.bed_outlined,
            message: 'No rooms on this floor',
            subtitle: 'Go back and select a different floor.',
          );
        }

        if (available.isEmpty) {
          return const _EmptyState(
            icon: Icons.no_meeting_room_outlined,
            iconColor: AppColors.error,
            message: 'All rooms are full',
            subtitle:
                'All rooms on this floor are occupied. Go back and try a different floor.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Room',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '${available.length} available room${available.length != 1 ? 's' : ''} · tap to select, then press Confirm',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                ),
                itemCount: rooms.length,
                itemBuilder: (context, i) {
                  final room = rooms[i];
                  final isFull = !room.isAvailable ||
                      room.occupied >= room.capacity;
                  final isSelected = selectedRoomId == room.id;

                  return _RoomCard(
                    room: room,
                    isFull: isFull,
                    isSelected: isSelected,
                    onTap: isFull ? null : () => onSelect(room),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Room Card ─────────────────────────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.isFull,
    required this.isSelected,
    required this.onTap,
  });

  final RoomModel room;
  final bool isFull;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Color cardColor;
    Color iconColor;
    if (isSelected) {
      cardColor = AppColors.primary;
      iconColor = Colors.white;
    } else if (isFull) {
      cardColor = AppColors.error.withValues(alpha: 0.07);
      iconColor = AppColors.error;
    } else {
      cardColor = AppColors.success.withValues(alpha: 0.07);
      iconColor = AppColors.success;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isFull
                    ? AppColors.error.withValues(alpha: 0.25)
                    : AppColors.success.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : isFull
                      ? Icons.no_meeting_room_rounded
                      : Icons.bed_rounded,
              size: 32,
              color: isSelected ? Colors.white : iconColor,
            ),
            const SizedBox(height: 8),
            Text(
              'Room ${room.name}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isFull
                  ? 'Full'
                  : '${room.capacity - room.occupied} bed${(room.capacity - room.occupied) != 1 ? 's' : ''} free',
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.85)
                    : isFull
                        ? AppColors.error
                        : AppColors.success,
              ),
            ),
            Text(
              'Cap: ${room.capacity}',
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.7)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confirm Bottom Bar ────────────────────────────────────────────────────────

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.hostel,
    required this.hall,
    required this.floor,
    required this.room,
    required this.isLoading,
    required this.onConfirm,
  });

  final HostelModel hostel;
  final HallModel hall;
  final FloorModel floor;
  final RoomModel room;
  final bool isLoading;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${hostel.name} · ${hall.name}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${floor.name} · Room ${room.name} · ${room.capacity - room.occupied} bed${(room.capacity - room.occupied) != 1 ? 's' : ''} free',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isLoading ? null : onConfirm,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Confirm',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Step List ──────────────────────────────────────────────────────────

class _StepList extends StatelessWidget {
  const _StepList(
      {required this.title,
      required this.subtitle,
      required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: children.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => children[i],
          ),
        ),
      ],
    );
  }
}

// ── Shared Tile ───────────────────────────────────────────────────────────────

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge!,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.info,
                        fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subtitle,
    this.iconColor,
    this.action,
  });

  final IconData icon;
  final String message;
  final String subtitle;
  final Color? iconColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 64,
                color: iconColor ??
                    AppColors.textDisabled),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── Error State ───────────────────────────────────────────────────────────────

class _StepError extends StatelessWidget {
  const _StepError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 56, color: AppColors.warning),
            const SizedBox(height: 16),
            const Text('Could not load data',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
