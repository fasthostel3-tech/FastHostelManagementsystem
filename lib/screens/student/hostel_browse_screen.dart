import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/hall_floor_room_service.dart';
import '../../models/hostel_model.dart' show HostelModel;
import '../../models/hall_floor_room_model.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class HostelBrowseScreen extends ConsumerStatefulWidget {
  const HostelBrowseScreen({super.key});

  @override
  ConsumerState<HostelBrowseScreen> createState() => _HostelBrowseScreenState();
}

class _HostelBrowseScreenState extends ConsumerState<HostelBrowseScreen> {
  String? _selectedHostelId;
  String? _selectedHallId;
  String? _selectedFloorId;

  @override
  Widget build(BuildContext context) {
    return ref.watch(currentUserProvider).when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('User not found')),
          );
        }

        final studentId = user.uid;
        final academicYear = (user.arnRollNumber.length >= 2)
            ? user.arnRollNumber.substring(0, 2)
            : null;

        final hallService = ref.watch(hallFloorRoomServiceProvider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Browse Hostels'),
          ),
          body: Column(
            children: [
              // Hostel Selector
              if (_selectedHostelId == null)
                Expanded(
                  child: _buildHostelList(hallService, studentId, academicYear),
                )
              // Hall Selector
              else if (_selectedHallId == null)
                Expanded(
                  child: _buildHallList(hallService),
                )
              // Floor Selector
              else if (_selectedFloorId == null)
                Expanded(
                  child: _buildFloorList(hallService),
                )
              // Room List
              else
                Expanded(
                  child: _buildRoomList(hallService),
                ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildHostelList(HallFloorRoomService service, String studentId, String? academicYear) {
    return StreamBuilder<List<HostelModel>>(
      stream: service.getVisibleHostelsForStudent(
        studentId: studentId,
        academicYear: academicYear,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final hostels = snapshot.data ?? [];

        if (hostels.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.home_work_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No hostels available',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: hostels.length,
          itemBuilder: (context, index) {
            final hostel = hostels[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: hostel.gender == 'male'
                      ? AppTheme.primaryColor.withValues(alpha: 0.1)
                      : AppTheme.errorColor.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.home_work,
                    color: hostel.gender == 'male'
                        ? AppTheme.primaryColor
                        : AppTheme.errorColor,
                  ),
                ),
                title: Text(
                  hostel.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gender: ${hostel.gender}'),
                    if (hostel.description.isNotEmpty)
                      Text(
                        hostel.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  setState(() => _selectedHostelId = hostel.id);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHallList(HallFloorRoomService service) {
    return Column(
      children: [
        // Back button and title
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedHostelId = null),
              ),
              Expanded(
                child: Text(
                  'Select Hall',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<HallModel>>(
            stream: service.getHallsForHostel(_selectedHostelId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final halls = snapshot.data ?? [];

              if (halls.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No halls found in this hostel',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: halls.length,
                itemBuilder: (context, index) {
                  final hall = halls[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.meeting_room,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      title: Text(
                        hall.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: hall.description != null
                          ? Text(hall.description!)
                          : null,
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        setState(() => _selectedHallId = hall.id);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFloorList(HallFloorRoomService service) {
    return Column(
      children: [
        // Back button and title
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedHallId = null),
              ),
              Expanded(
                child: Text(
                  'Select Floor',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<FloorModel>>(
            stream: service.getFloorsForHall(_selectedHallId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final floors = snapshot.data ?? [];

              if (floors.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.layers_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No floors found in this hall',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: floors.length,
                itemBuilder: (context, index) {
                  final floor = floors[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.infoColor.withValues(alpha: 0.1),
                        child: Text(
                          '${floor.floorNumber}',
                          style: const TextStyle(
                            color: AppTheme.infoColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        floor.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: floor.description != null
                          ? Text(floor.description!)
                          : null,
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        setState(() => _selectedFloorId = floor.id);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoomList(HallFloorRoomService service) {
    return Column(
      children: [
        // Back button and title
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedFloorId = null),
              ),
              Expanded(
                child: Text(
                  'Available Rooms',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<RoomModel>>(
            stream: service.getRoomsForFloor(_selectedFloorId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final rooms = snapshot.data ?? [];

              if (rooms.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bed_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No rooms found on this floor',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.95,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  final statusColor = room.isAvailable
                      ? AppColors.roomAvailable
                      : AppColors.roomOccupied;
                  return Card(
                    elevation: 2,
                    shadowColor: statusColor.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: statusColor, width: 1.5),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showRoomDetails(service, room),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                room.isAvailable ? Icons.bed : Icons.bed_outlined,
                                size: 28,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              room.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${room.occupied}/${room.capacity} beds',
                              style: TextStyle(
                                fontSize: 13,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              room.isAvailable
                                  ? '${room.availableBeds} available'
                                  : 'Full',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showRoomDetails(HallFloorRoomService service, RoomModel room) {
    final statusColor =
        room.isAvailable ? AppColors.roomAvailable : AppColors.roomOccupied;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Room name + status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.meeting_room, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        room.isAvailable ? 'Available' : 'Fully Occupied',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            _buildDetailRow('Total Beds', '${room.capacity}'),
            _buildDetailRow('Occupied Beds', '${room.occupied}'),
            _buildDetailRow('Available Beds', '${room.availableBeds}'),
            if (room.description != null) ...[
              const SizedBox(height: 8),
              Text(
                room.description!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: room.isAvailable
                    ? () => Navigator.of(context).pop()
                    : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Select This Room'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      room.isAvailable ? AppColors.primary : AppColors.textDisabled,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}


