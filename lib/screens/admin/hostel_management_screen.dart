import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/hostel_service.dart';
import '../../services/hall_floor_room_service.dart';
import '../../models/hostel_model.dart';
import '../../config/theme.dart';

class HostelManagementScreen extends ConsumerStatefulWidget {
  const HostelManagementScreen({super.key});

  @override
  ConsumerState<HostelManagementScreen> createState() =>
      _HostelManagementScreenState();
}

class _HostelManagementScreenState
    extends ConsumerState<HostelManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hallsController = TextEditingController();

  String _selectedGender = 'male';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _hallsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hostelService = ref.watch(hostelServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hostel Management'),
        actions: [
          FloatingActionButton(
            onPressed: _showAddHostelDialog,
            mini: true,
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<List<HostelModel>>(
        stream: hostelService.getAllHostels(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final hostels = snapshot.data ?? [];

          if (hostels.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.home_work, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No hostels found'),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _showAddHostelDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Add First Hostel',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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
                        ? AppTheme.primaryColor.withValues(alpha:0.1)
                        : AppTheme.errorColor.withValues(alpha:0.1),
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
                      Text('${hostel.totalFloors} halls'),
                      Text('Gender: ${hostel.gender}'),
                      if (hostel.description.isNotEmpty)
                        Text(
                          hostel.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'visibility':
                          _showVisibilityDialog(hostel);
                          break;
                        case 'edit':
                          _showEditHostelDialog(hostel);
                          break;
                        case 'delete':
                          _showDeleteConfirmation(hostel);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'visibility',
                        child: Row(
                          children: [
                            Icon(Icons.visibility),
                            SizedBox(width: 8),
                            Text('Manage Visibility'),
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddHostelDialog() {
    _nameController.clear();
    _descriptionController.clear();
    _hallsController.clear();
    _selectedGender = 'male';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Hostel'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Hostel Name',
                  hintText: 'e.g., Jinnah Hall',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter hostel name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                ),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                ],
                onChanged: (value) {
                  setState(() => _selectedGender = value!);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hallsController,
                decoration: const InputDecoration(
                  labelText: 'Number of Halls',
                  hintText: 'e.g., 4',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number of halls';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional description',
                ),
                maxLines: 3,
              ),
            ],
          ),
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
            onTap: _isLoading ? null : _addHostel,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
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
    );
  }

  void _showEditHostelDialog(HostelModel hostel) {
    _nameController.text = hostel.name;
    _descriptionController.text = hostel.description;
    _hallsController.text = hostel.totalFloors.toString();
    _selectedGender = hostel.gender;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Hostel'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Hostel Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter hostel name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                ),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                ],
                onChanged: (value) {
                  setState(() => _selectedGender = value!);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hallsController,
                decoration: const InputDecoration(
                  labelText: 'Number of Halls',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number of halls';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
                maxLines: 3,
              ),
            ],
          ),
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
            onTap: _isLoading ? null : () => _editHostel(hostel),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
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
    );
  }

  void _showDeleteConfirmation(HostelModel hostel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Hostel'),
        content: Text('Are you sure you want to delete ${hostel.name}?'),
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
            onTap: () {
              Navigator.of(context).pop();
              _deleteHostel(hostel);
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

  Future<void> _addHostel() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final hostelService = ref.read(hostelServiceProvider);
      await hostelService.createHostel(
        name: _nameController.text.trim(),
        gender: _selectedGender,
        totalFloors: int.parse(_hallsController.text),
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hostel added successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding hostel: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editHostel(HostelModel hostel) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final hostelService = ref.read(hostelServiceProvider);
      await hostelService.updateHostel(
        hostelId: hostel.id,
        name: _nameController.text.trim(),
        gender: _selectedGender,
        totalFloors: int.parse(_hallsController.text),
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hostel updated successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating hostel: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteHostel(HostelModel hostel) async {
    setState(() => _isLoading = true);

    try {
      final hostelService = ref.read(hostelServiceProvider);
      await hostelService.deleteHostel(hostel.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hostel deleted successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting hostel: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showVisibilityDialog(HostelModel hostel) {
    final hallService = ref.read(hallFloorRoomServiceProvider);
    final studentIdsController = TextEditingController();
    final academicYearsController = TextEditingController();
    bool isLoading = false;

    // Load existing visibility
    hallService.getHostelVisibility(hostel.id).then((visibility) {
      if (visibility != null && mounted) {
        studentIdsController.text = visibility.visibleToStudentIds.join(', ');
        academicYearsController.text = visibility.visibleToAcademicYears.join(', ');
      }
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Manage Visibility: ${hostel.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Control which students can see this hostel. Leave empty to allow all students.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: studentIdsController,
                  decoration: const InputDecoration(
                    labelText: 'Student IDs (comma separated)',
                    hintText: 'e.g., uid1, uid2, uid3',
                    border: OutlineInputBorder(),
                    helperText: 'Leave empty to allow all students',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: academicYearsController,
                  decoration: const InputDecoration(
                    labelText: 'Academic Years (comma separated)',
                    hintText: 'e.g., Freshman, Sophomore, Junior',
                    border: OutlineInputBorder(),
                    helperText: 'Leave empty to allow all years',
                  ),
                ),
              ],
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
                      setDialogState(() => isLoading = true);
                      try {
                        final studentIds = studentIdsController.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        final academicYears = academicYearsController.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();

                        await hallService.setHostelVisibility(
                          hostelId: hostel.id,
                          visibleToStudentIds: studentIds.isEmpty ? null : studentIds,
                          visibleToAcademicYears: academicYears.isEmpty ? null : academicYears,
                        );

                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Visibility settings saved!'),
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
                        'Save',
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
}




