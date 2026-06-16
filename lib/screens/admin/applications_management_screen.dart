import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/hostel_service.dart';
import '../../services/hall_floor_room_service.dart';
import '../../models/hostel_model.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class ApplicationsManagementScreen extends ConsumerStatefulWidget {
  const ApplicationsManagementScreen({super.key});

  @override
  ConsumerState<ApplicationsManagementScreen> createState() => _ApplicationsManagementScreenState();
}

class _ApplicationsManagementScreenState extends ConsumerState<ApplicationsManagementScreen> {
  String _selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final hostelService = ref.watch(hostelServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications Management'),
        actions: [
          DropdownButton<String>(
            value: _selectedStatus,
            onChanged: (value) {
              setState(() => _selectedStatus = value!);
            },
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Applications')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'approved', child: Text('Approved')),
              DropdownMenuItem(value: 'fee_challan_generated', child: Text('Fee Challan Generated')),
              DropdownMenuItem(value: 'fee_confirmed', child: Text('Fee Confirmed')),
              DropdownMenuItem(value: 'room_assigned', child: Text('Room Assigned')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<HostelApplicationModel>>(
        stream: hostelService.getAllApplications(),
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
          
          final applications = snapshot.data ?? [];
          final filteredApplications = _selectedStatus == 'all' 
              ? applications 
              : applications.where((app) => app.status == _selectedStatus).toList();
          
          if (filteredApplications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(_selectedStatus == 'all' 
                      ? 'No applications found' 
                      : 'No $_selectedStatus applications found'),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredApplications.length,
            itemBuilder: (context, index) {
              final application = filteredApplications[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(
                    application.studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(application.studentEmail),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStatusChip(application.status),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM d, y').format(application.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Application Details
                          _buildDetailRow('ARN/Roll Number', application.rollNumber),
                          _buildDetailRow('Room Type', application.roomType.toString().split('.').last.toUpperCase()),
                          _buildDetailRow('City', application.city),
                          _buildDetailRow('Fee Amount', '${application.feeAmount.toStringAsFixed(0)} PKR'),
                          _buildDetailRow('CNIC Image', 'Uploaded'),
                          
                          const SizedBox(height: 16),
                          
                          // CNIC Image
                          if (application.cnicImageUrl.isNotEmpty) ...[
                            Text(
                              'CNIC Document',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.withValues(alpha:0.3)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  application.cnicImageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(Icons.error, color: Colors.red),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // Action Buttons
                          Row(
                            children: [
                              if (application.status == 'pending') ...[
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _approveAndSendChallan(application),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.check, color: Colors.white, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'Approve & Send Challan',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _rejectApplication(application),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.close, color: Colors.white, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'Reject',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ] else if (application.status == 'approved' || application.status == 'fee_challan_generated') ...[
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _approveAndSendChallan(application),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningColor,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.receipt, color: Colors.white, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'Send / Resend Challan',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (application.status == 'fee_challan_generated') ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _confirmFeePayment(application),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.payment, color: Colors.white, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              'Confirm Fee Payment',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ] else if (application.status == 'fee_confirmed') ...[
                                _StudentRoomRequestSection(
                                  application: application,
                                  onAssignManually: () =>
                                      _assignRoom(application),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'pending':
        color = AppTheme.warningColor;
        break;
      case 'approved':
        color = AppTheme.infoColor;
        break;
      case 'fee_challan_generated':
        color = AppTheme.primaryColor;
        break;
      case 'fee_confirmed':
        color = AppTheme.successColor;
        break;
      case 'room_assigned':
        color = AppTheme.successColor;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _approveApplication(HostelApplicationModel application) async {
    try {
      final hostelService = ref.read(hostelServiceProvider);
      await hostelService.updateApplicationStatus(
        applicationId: application.id,
        status: 'approved',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application approved successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving application: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _rejectApplication(HostelApplicationModel application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: const Text('Are you sure you want to reject this application?'),
        actions: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(false),
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
            onTap: () => Navigator.of(context).pop(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Reject',
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

    if (confirmed != true) return;

    try {
      final hostelService = ref.read(hostelServiceProvider);
      await hostelService.updateApplicationStatus(
        applicationId: application.id,
        status: 'rejected',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application rejected'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting application: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _approveAndSendChallan(HostelApplicationModel application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve & Send Challan'),
        content: const Text(
          'Are you sure you want to approve this application and generate a fee challan? The global Accommodation Bank Details will be used.',
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(false),
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
            onTap: () => Navigator.of(context).pop(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Approve & Send',
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

    if (confirmed != true) return;

    if (!mounted) return;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch accommodation bank details automatically
      final settingsDoc = await FirebaseFirestore.instance.collection('settings').doc('bankDetailsAccommodation').get();
      String bankName = '';
      String accountNumber = '';
      String accountTitle = '';
      
      if (settingsDoc.exists && settingsDoc.data() != null) {
        final data = settingsDoc.data()!;
        bankName = data['bankName'] ?? '';
        accountNumber = data['accountNumber'] ?? '';
        accountTitle = data['accountTitle'] ?? '';
      }
      
      if (bankName.isEmpty || accountNumber.isEmpty) {
         throw Exception('Global Accommodation Bank Details are not set. Please set them in Bank Settings first.');
      }

      final hostelService = ref.read(hostelServiceProvider);
      // First mark as approved to align with the flow
      await hostelService.updateApplicationStatus(
        applicationId: application.id,
        status: 'approved',
      );
      // Then generate challan with global bank details
      await hostelService.generateFeeChallan(
        applicationId: application.id,
        bankName: bankName,
        accountNumber: accountNumber,
        accountTitle: accountTitle,
      );
      
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Approved and challan sent to student!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        final errorMessage = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending challan: $errorMessage'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmFeePayment(HostelApplicationModel application) async {
    try {
      final hostelService = ref.read(hostelServiceProvider);
      await hostelService.confirmFeePayment(application.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fee payment confirmed successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error confirming fee payment: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _assignRoom(HostelApplicationModel application) async {
    if (!mounted) return;
    context.push('/admin/dashboard/room-requests');
  }
}

// ── Student Room Request Section ─────────────────────────────────────────────
// Shown inside the fee_confirmed expansion tile.
// Fetches the pending roomRequest for this application and displays the
// student's selected room details with a direct "Approve Room" button.

class _StudentRoomRequestSection extends ConsumerStatefulWidget {
  const _StudentRoomRequestSection({
    required this.application,
    required this.onAssignManually,
  });

  final HostelApplicationModel application;
  final VoidCallback onAssignManually;

  @override
  ConsumerState<_StudentRoomRequestSection> createState() =>
      _StudentRoomRequestSectionState();
}

class _StudentRoomRequestSectionState
    extends ConsumerState<_StudentRoomRequestSection> {
  bool _isApproving = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchRoomRequest(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final request = snap.data;

        if (request == null) {
          // No room request yet — show standard Assign Room button
          return _actionButton(
            label: 'Assign Room',
            icon: Icons.room,
            color: AppTheme.infoColor,
            onTap: widget.onAssignManually,
          );
        }

        final requestId = request['id'] as String;
        final roomDetails =
            request['roomDetails'] as Map<String, dynamic>?;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Student's selected room card ─────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.how_to_reg_rounded,
                          color: AppColors.info, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Student\'s Room Selection',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.info,
                            ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Pending Approval',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (roomDetails != null) ...[
                    _infoRow(Icons.home_work_rounded, 'Hostel',
                        roomDetails['hostelName'] ?? '—'),
                    const SizedBox(height: 6),
                    _infoRow(Icons.meeting_room_rounded, 'Hall',
                        roomDetails['hallName'] ?? '—'),
                    const SizedBox(height: 6),
                    _infoRow(Icons.layers_rounded, 'Floor',
                        roomDetails['floorName'] ?? '—'),
                    const SizedBox(height: 6),
                    _infoRow(Icons.bed_rounded, 'Room',
                        'Room ${roomDetails['roomName'] ?? '—'}'),
                    const SizedBox(height: 6),
                    _infoRow(
                      Icons.people_outline,
                      'Capacity',
                      '${roomDetails['capacity'] ?? '—'} beds · ${roomDetails['available'] ?? '—'} free',
                    ),
                  ] else ...[
                    const Text('Room details loading...',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Action buttons ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    label: _isApproving
                        ? 'Approving...'
                        : 'Approve This Room',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.success,
                    onTap: _isApproving
                        ? null
                        : () => _approveRequest(requestId),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                    label: 'Change Room',
                    icon: Icons.swap_horiz_rounded,
                    color: AppColors.warning,
                    onTap: widget.onAssignManually,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: onTap == null
              ? color.withValues(alpha: 0.4)
              : color,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchRoomRequest() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('roomRequests')
          .where('applicationId', isEqualTo: widget.application.id)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;

      final data = Map<String, dynamic>.from(snap.docs.first.data());
      data['id'] = snap.docs.first.id;

      // Fetch full room details
      final roomId = data['roomId'] as String?;
      if (roomId != null && roomId.isNotEmpty) {
        final roomDetails = await HallFloorRoomService()
            .getRoomFullDetails(roomId);
        data['roomDetails'] = roomDetails;
      }

      return data;
    } catch (e) {
      debugPrint('_fetchRoomRequest error: $e');
      return null;
    }
  }

  Future<void> _approveRequest(String requestId) async {
    setState(() => _isApproving = true);
    try {
      final admin = ref.read(currentUserProvider).value;
      await ref.read(hostelServiceProvider).approveRoomRequest(
            requestId,
            processedBy: admin?.uid,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room approved and assigned to student!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }
}















