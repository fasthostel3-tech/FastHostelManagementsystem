import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/hostel_service.dart';
import '../../../services/hall_floor_room_service.dart';
import '../../../models/hostel_model.dart';
import '../../../config/theme.dart';

class HostelApplicationScreen extends ConsumerStatefulWidget {
  const HostelApplicationScreen({super.key});

  @override
  ConsumerState<HostelApplicationScreen> createState() =>
      _HostelApplicationScreenState();
}

class _HostelApplicationScreenState
    extends ConsumerState<HostelApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cityController = TextEditingController();
  final _imagePicker = ImagePicker();

  RoomType _selectedRoomType = RoomType.shared;
  bool _isLoading = false;
  Object? _cnicImage; // can be dart:io File on mobile or XFile on web

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  // Extract academic year from roll number (first 2 digits)
  String _extractAcademicYear(String rollNumber) {
    if (rollNumber.length >= 2) {
      return rollNumber.substring(0, 2);
    }
    return '';
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    // Get roll number from user profile
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not found. Please sign in again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final rollNumber = currentUser.arnRollNumber;
    if (rollNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Roll number not found in profile. Please update your profile.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Extract academic year from roll number (first 2 digits)
    final academicYear = _extractAcademicYear(rollNumber);
    if (academicYear.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not extract academic year from roll number'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate CNIC upload
    if (_cnicImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your CNIC image before submitting'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        throw Exception('User not found');
      }

      final hostelService = ref.read(hostelServiceProvider);
      // On web, pass the XFile directly. On mobile, we also pass XFile since
      // the service handles both XFile and File objects.
      await hostelService.submitHostelApplication(
        studentId: currentUser.uid,
        studentName: currentUser.name,
        studentEmail: currentUser.email,
        rollNumber: rollNumber,
        academicYear: academicYear,
        roomType: _selectedRoomType,
        city: _cityController.text.trim(),
        cnicImage: _cnicImage, // XFile works on all platforms
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting application: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hostel Application'),
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          // Check for existing application
          return StreamBuilder(
            stream: ref
                .read(hostelServiceProvider)
                .getUserApplicationStream(user.uid),
            builder: (context, snapshot) {
              final application = snapshot.data;

              // If room is assigned, show room details
              if (application?.status == 'room_assigned') {
                return _buildRoomDetails(context, user.uid);
              }

              // If application exists and is pending/approved, show status
              if (application != null && application.status != 'rejected') {
                return _buildApplicationStatus(context, application);
              }

              // No application or rejected - show form
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryLight,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hostel Application',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Apply for hostel accommodation',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Student Information
                      Text(
                        'Student Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),

                      _buildInfoCard(context, 'Name', user.name),
                      const SizedBox(height: 12),
                      _buildInfoCard(context, 'Email', user.email),
                      const SizedBox(height: 12),
                      _buildInfoCard(context, 'Gender',
                          user.gender.toString().split('.').last.toUpperCase()),

                      const SizedBox(height: 24),

                      // Application Details
                      Text(
                        'Application Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // Display Roll Number from Profile (read-only)
                      Consumer(
                        builder: (context, ref, child) {
                          final currentUserAsync =
                              ref.watch(currentUserProvider);
                          final user = currentUserAsync.value;
                          final rollNumber = user?.arnRollNumber ?? '';
                          final academicYear = rollNumber.isNotEmpty
                              ? _extractAcademicYear(rollNumber)
                              : '';

                          if (rollNumber.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.warningColor
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.warning,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Roll number not found in profile. Please update your profile.',
                                      style: TextStyle(
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.badge,
                                      color: AppTheme.primaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Roll Number: $rollNumber',
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (academicYear.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.school,
                                        color: AppTheme.primaryColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Academic Year: $academicYear',
                                        style: const TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Room Type Selection
                      Text(
                        'Preferred Room Type',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 8),

                      ...RoomType.values.map((type) {
                        final fee = HostelApplicationModel.getFeeAmount(type);
                        return Card(
                          child: RadioListTile<RoomType>(
                            title: Text(
                                type.toString().split('.').last.toUpperCase()),
                            subtitle:
                                Text('Fee: ${fee.toStringAsFixed(0)} PKR'),
                            value: type,
                            groupValue: _selectedRoomType,
                            onChanged: (value) {
                              setState(() => _selectedRoomType = value!);
                            },
                          ),
                        );
                      }),

                      const SizedBox(height: 16),

                      // City Input
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          hintText: 'Enter your city',
                          prefixIcon: Icon(Icons.location_city),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your city';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // CNIC Upload
                      Text(
                        'CNIC Document',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.3),
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _cnicImage == null
                            ? InkWell(
                                onTap: _pickCnicImage,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.upload_file,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Upload CNIC Image',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap to select image',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.grey[500],
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            : Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Builder(
                                      builder: (context) {
                                        if (_cnicImage == null) {
                                          return const SizedBox.shrink();
                                        }

                                        // XFile works on both web and mobile platforms
                                        final xFile = _cnicImage as XFile;
                                        return FutureBuilder<Uint8List>(
                                          future: xFile.readAsBytes(),
                                          builder: (context, snapshot) {
                                            if (!snapshot.hasData) {
                                              return const Center(
                                                  child:
                                                      CircularProgressIndicator());
                                            }
                                            return Image.memory(
                                              snapshot.data!,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.contain,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          _cnicImage = null;
                                        });
                                      },
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please upload a clear image of your CNIC (National ID Card)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),

                      const SizedBox(height: 24),

                      // Terms and Conditions
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    color: AppColors.warning),
                                const SizedBox(width: 8),
                                Text(
                                  'Important Terms',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.warningColor,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Applications are processed on a first-come, first-served basis\n'
                              '• Fee payment must be completed within 7 days of approval\n'
                              '• Room assignment will be based on availability and preferences\n'
                              '• Cancellation policy applies as per hostel rules',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey[700],
                                  ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitApplication,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text('Submit Application'),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading data: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(currentUserProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCnicImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _cnicImage = image; // Store XFile directly
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildInfoCard(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationStatus(
      BuildContext context, HostelApplicationModel application) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (application.status) {
      case 'pending':
        statusText = 'Application Under Review';
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'approved':
        statusText = 'Approved - Challan will be sent soon';
        statusColor = AppTheme.infoColor;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'fee_challan_generated':
        statusText = 'Challan Issued - Please pay and upload proof';
        statusColor = AppTheme.primaryColor;
        statusIcon = Icons.receipt_long;
        break;
      case 'fee_confirmed':
        statusText = 'Payment Verified - Proceed to room assignment';
        statusColor = AppTheme.successColor;
        statusIcon = Icons.verified;
        break;
      default:
        statusText = application.status.replaceAll('_', ' ').toUpperCase();
        statusColor = Colors.grey;
        statusIcon = Icons.info_outline;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor,
                  statusColor.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(statusIcon, size: 64, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your application is being processed',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Application Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(context, 'Application ID', application.id),
          const SizedBox(height: 12),
          _buildInfoCard(context, 'Room Type',
              application.roomType.toString().split('.').last.toUpperCase()),
          const SizedBox(height: 12),
          _buildInfoCard(context, 'Fee Amount',
              '${application.feeAmount.toStringAsFixed(0)} PKR'),
          const SizedBox(height: 12),
          _buildInfoCard(context, 'City', application.city),
          const SizedBox(height: 12),
          _buildInfoCard(context, 'Submitted On',
              '${application.createdAt.day}/${application.createdAt.month}/${application.createdAt.year}'),
          if (application.status == 'fee_challan_generated' ||
              application.status == 'fee_confirmed') ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.infoColor.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.infoColor),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please check the Payments section to view your challan, pay the fee, and upload proof so admin can verify.',
                      style: TextStyle(
                          color: AppTheme.infoColor,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoomDetails(BuildContext context, String studentId) {
    return FutureBuilder(
      future: HallFloorRoomService().getStudentBedDetails(studentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                    'Error loading room details: ${snapshot.error ?? 'Room details not found'}'),
              ],
            ),
          );
        }

        final roomDetails = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.successColor,
                      AppTheme.successColor.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.home, size: 64, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'Room Assigned',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your accommodation has been confirmed',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Room Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              _buildInfoCard(context, 'Hall', roomDetails['hallName'] ?? 'N/A'),
              const SizedBox(height: 12),
              _buildInfoCard(
                  context, 'Floor', roomDetails['floorName'] ?? 'N/A'),
              const SizedBox(height: 12),
              _buildInfoCard(context, 'Room', roomDetails['roomName'] ?? 'N/A'),
              const SizedBox(height: 12),
              _buildInfoCard(
                  context, 'Bed Number', roomDetails['bedNumber'] ?? 'N/A'),
            ],
          ),
        );
      },
    );
  }
}
