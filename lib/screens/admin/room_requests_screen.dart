import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/hostel_service.dart';
import '../../services/hall_floor_room_service.dart';
import '../../services/profile_service.dart';

class RoomRequestsScreen extends ConsumerWidget {
  const RoomRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostelService = ref.watch(hostelServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Requests'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: hostelService.getPendingRoomRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return const Center(child: Text('No pending room requests'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final requestId = req['id'] as String;
              final studentId = req['studentId'] as String;
              final roomId = req['roomId'] as String;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: FutureBuilder<Map<String, dynamic>?>(
                    future: ref
                        .read(profileServiceProvider)
                        .getProfile(studentId)
                        .then((p) => p?.toMap()),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Text('Loading...');
                      }
                      final data = snap.data;
                      final name = data != null
                          ? (data['name'] ?? 'Unknown')
                          : 'Unknown';
                      return InkWell(
                        onTap: () async {
                          // Show full profile preview
                          final profile = await ref
                              .read(profileServiceProvider)
                              .getProfile(studentId);
                          if (!context.mounted) return;
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(profile?.name ?? 'Profile'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (profile?.profileImage != null)
                                    Image.network(profile?.profileImage ?? '',
                                        height: 120),
                                  const SizedBox(height: 8),
                                  Text('Email: ${profile?.email ?? '-'}'),
                                  Text('Phone: ${profile?.phoneNumber ?? '-'}'),
                                  Text('Room: ${profile?.roomNumber ?? '-'}'),
                                  Text(
                                      'Joined: ${profile != null ? profile.joinDate.toLocal().toString().split(' ').first : '-'}'),
                                ],
                              ),
                              actions: [
                                GestureDetector(
                                    onTap: () => Navigator.of(ctx).pop(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        'Close',
                                        style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )),
                              ],
                            ),
                          );
                        },
                        child: Text(name),
                      );
                    },
                  ),
                  subtitle: FutureBuilder(
                    future: ref.read(hallFloorRoomServiceProvider).getRoom(roomId),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Text('Loading room...');
                      }
                      final room = snap.data;
                      final roomNumber = room?.name ?? roomId;
                      return Text('Requested Room: $roomNumber');
                    },
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      GestureDetector(
                        onTap: () async {
                          // Prompt for optional admin note
                          final note = await showDialog<String?>(
                            context: context,
                            builder: (ctx) {
                              final ctrl = TextEditingController();
                              return AlertDialog(
                                title: const Text('Approve Request'),
                                content: TextField(
                                  controller: ctrl,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                      hintText: 'Optional note to student'),
                                ),
                                actions: [
                                  GestureDetector(
                                      onTap: () => Navigator.of(ctx).pop(null),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600),
                                        ),
                                      )),
                                  GestureDetector(
                                      onTap: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Approve',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      )),
                                ],
                              );
                            },
                          );

                          if (note == null && !context.mounted) {
                            return; // cancelled
                          }
                          try {
                            await ref
                                .read(hostelServiceProvider)
                                .approveRoomRequest(requestId,
                                    adminNote: note ?? '');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Request approved')));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                        child: Text(
                          'Approve',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          // Prompt for rejection reason
                          final reason = await showDialog<String?>(
                            context: context,
                            builder: (ctx) {
                              final ctrl = TextEditingController();
                              return AlertDialog(
                                title: const Text('Reject Request'),
                                content: TextField(
                                  controller: ctrl,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                      hintText:
                                          'Reason for rejection (optional)'),
                                ),
                                actions: [
                                  GestureDetector(
                                      onTap: () => Navigator.of(ctx).pop(null),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600),
                                        ),
                                      )),
                                  GestureDetector(
                                      onTap: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Reject',
                                            style:
                                                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      )),
                                ],
                              );
                            },
                          );

                          if (reason == null && !context.mounted) return;
                          try {
                            await ref
                                .read(hostelServiceProvider)
                                .rejectRoomRequest(requestId,
                                    reason: reason ?? '');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Request rejected')));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')));
                            }
                          }
                        },
                        child: const Text('Reject',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
