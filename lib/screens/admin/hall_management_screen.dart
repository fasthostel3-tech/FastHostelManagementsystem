import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/hostel_service.dart';
import '../../services/hall_floor_room_service.dart';
import '../../models/hostel_model.dart';
import '../../models/hall_floor_room_model.dart';
import '../../config/theme.dart';

class HallManagementScreen extends ConsumerStatefulWidget {
  const HallManagementScreen({super.key});

  @override
  ConsumerState<HallManagementScreen> createState() => _HallManagementScreenState();
}

class _HallManagementScreenState extends ConsumerState<HallManagementScreen> {
  String? _selectedHostelId;

  @override
  Widget build(BuildContext context) {
    final hostelService = ref.watch(hostelServiceProvider);
    final hallService = ref.watch(hallFloorRoomServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hall Management'),
        actions: [
          if (_selectedHostelId != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddHallDialog(hallService),
              tooltip: 'Add Hall',
            ),
        ],
      ),
      body: Column(
        children: [
          // Hostel Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surface,
            child: StreamBuilder<List<HostelModel>>(
              stream: hostelService.getAllHostels(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final hostels = snapshot.data ?? [];
                if (hostels.isEmpty) {
                  return const Text('No hostels available. Create a hostel first.');
                }

                      return DropdownButtonFormField<String>(
                  initialValue: _selectedHostelId,
                        decoration: const InputDecoration(
                    labelText: 'Select Hostel',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.home_work),
                  ),
                        items: [
                          const DropdownMenuItem(
                      value: null,
                      child: Text('Select a hostel...'),
                    ),
                    ...hostels.map((hostel) => DropdownMenuItem(
                          value: hostel.id,
                          child: Text(hostel.name),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedHostelId = value);
                  },
                      );
                    },
                  ),
                ),

          // Halls List
                Expanded(
            child: _selectedHostelId == null
                ? Center(
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
                          'Select a hostel to view halls',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  )
                : StreamBuilder<List<HallModel>>(
                    stream: hallService.getHallsForHostel(_selectedHostelId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
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
                                'No halls found',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showAddHallDialog(hallService),
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Hall'),
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
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'manage':
                                      context.push('/admin/dashboard/halls/${hall.id}');
                                      break;
                                    case 'edit':
                                      _showEditHallDialog(hallService, hall);
                                      break;
                                    case 'delete':
                                      _showDeleteHallDialog(hallService, hall);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'manage',
                                    child: Row(
                                      children: [
                                        Icon(Icons.settings),
                                        SizedBox(width: 8),
                                        Text('Manage Floors & Rooms'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                      ),
                      onTap: () {
                                context.push('/admin/dashboard/halls/${hall.id}');
                      },
                            ),
                );
              },
                      );
                    },
                  ),
            ),
        ],
      ),
    );
  }

  void _showAddHallDialog(HallFloorRoomService service) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

                                    showDialog(
                                      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Hall'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                  children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Hall Name',
                      hintText: 'e.g., Jinnah Hall, Iqbal Hall',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter hall name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
                                          actions: [
                                            GestureDetector(
              onTap: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() => isLoading = true);
                      try {
                        await service.createHall(
                          hostelId: _selectedHostelId!,
                          name: nameController.text.trim(),
                          description: descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                        );

                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Hall added successfully!'),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setDialogState(() => isLoading = false);
                        }
                      }
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Add',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHallDialog(HallFloorRoomService service, HallModel hall) {
    final nameController = TextEditingController(text: hall.name);
    final descriptionController = TextEditingController(text: hall.description ?? '');
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Hall'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Hall Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter hall name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                                      ],
                                    ),
                                  ),
          ),
          actions: [
            GestureDetector(
              onTap: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() => isLoading = true);
                      try {
                        await service.updateHall(
                          hallId: hall.id,
                          name: nameController.text.trim(),
                          description: descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                        );

                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Hall updated successfully!'),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          setDialogState(() => isLoading = false);
                        }
                      }
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Update',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteHallDialog(HallFloorRoomService service, HallModel hall) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Hall'),
        content: Text(
          'Are you sure you want to delete "${hall.name}"?\n\nThis will also delete all floors, rooms, and beds in this hall.',
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              Navigator.of(context).pop();
              try {
                await service.deleteHall(hall.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hall deleted successfully!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
