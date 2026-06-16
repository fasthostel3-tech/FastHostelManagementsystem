import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/gym_service.dart';
import '../../services/payment_service.dart';
import '../../config/theme.dart';
import '../../widgets/status_badge.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class GymRegistrationScreen extends ConsumerStatefulWidget {
  const GymRegistrationScreen({super.key});

  @override
  ConsumerState<GymRegistrationScreen> createState() =>
      _GymRegistrationScreenState();
}

class _GymRegistrationScreenState
    extends ConsumerState<GymRegistrationScreen> {
  bool _isLoading = false;

  Future<void> _registerForGym() async {
    // ── Confirmation dialog ────────────────────────────────────────────────
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Gym Registration'),
        content: const Text(
          'Are you sure you want to register for gym access?\n\n'
          'Your request will be reviewed by an admin and you '
          'will be notified once approved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('User not found');

      final gymService = ref.read(gymServiceProvider);
      await gymService.registerForGym(
        studentId: currentUser.uid,
        studentName: currentUser.name,
        studentEmail: currentUser.email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gym registration request submitted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
        title: const Text('Gym Registration'),
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero header ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Gym Registration',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Register for gym access at FAST Hostel',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Registration info ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.info.withValues(alpha: 0.25)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.info),
                          SizedBox(width: 8),
                          Text(
                            'Registration Details',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        '• Registration is valid for 1 year\n'
                        '• Registration fee: PKR 2,000 / year\n'
                        '• You must submit the fee challan after registering\n'
                        '• Access will be granted after payment confirmation',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Current registration status ───────────────────────────
                Text(
                  'My Registration',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),

                StreamBuilder<Map<String, dynamic>?>(
                  stream: ref
                      .read(gymServiceProvider)
                      .getUserRegistration(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final registration = snapshot.data;

                    if (registration == null) {
                      // Not registered
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Icon(Icons.fitness_center_outlined,
                                  size: 56, color: AppColors.textDisabled),
                              const SizedBox(height: 12),
                              const Text(
                                'No Active Registration',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Submit a registration request to get gym access',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isLoading ? null : _registerForGym,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.add),
                                  label: Text(_isLoading
                                      ? 'Submitting...'
                                      : 'Register & Generate Fee'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final status =
                        registration['status'] as String? ?? 'pending';
                    final registrationDate =
                        registration['registrationDate'] as Timestamp?;
                    final expiryDate =
                        registration['expiryDate'] as Timestamp?;

                    // Countdown calculation
                    int? daysLeft;
                    if (expiryDate != null) {
                      daysLeft = expiryDate
                          .toDate()
                          .difference(DateTime.now())
                          .inDays;
                    }

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Status',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const Spacer(),
                                StatusBadge(
                                  label: status.toUpperCase(),
                                  type: status == 'active'
                                      ? StatusType.success
                                      : status == 'payment_uploaded'
                                          ? StatusType.info
                                          : status == 'rejected'
                                              ? StatusType.error
                                              : StatusType.warning,
                                ),
                              ],
                            ),

                            if (registrationDate != null) ...[
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              _InfoRow(
                                icon: Icons.calendar_today,
                                label: 'Registration Date',
                                value: DateFormat('MMM dd, yyyy')
                                    .format(registrationDate.toDate()),
                              ),
                            ],

                            if (expiryDate != null) ...[
                              const SizedBox(height: 8),
                              _InfoRow(
                                icon: Icons.event,
                                label: 'Expiry Date',
                                value: DateFormat('MMM dd, yyyy')
                                    .format(expiryDate.toDate()),
                              ),
                              if (daysLeft != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: daysLeft > 30
                                        ? AppColors.success.withValues(alpha: 0.10)
                                        : AppColors.warning
                                            .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        daysLeft > 30
                                            ? Icons.check_circle_outline
                                            : Icons.warning_amber_rounded,
                                        size: 16,
                                        color: daysLeft > 30
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        daysLeft > 0
                                            ? 'Expires in $daysLeft days'
                                            : 'Expired ${-daysLeft} days ago',
                                        style: TextStyle(
                                          color: daysLeft > 30
                                              ? AppColors.success
                                              : AppColors.warning,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],

                            if (status == 'pending_payment') ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.info
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Your registration requires fee payment. '
                                      'Please upload your fee challan screenshot below or from the Payments section.',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _UploadProofButton(
                                      registrationId: registration['id'],
                                      paymentId: registration['paymentId'],
                                      userId: user.uid,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (status == 'payment_uploaded') ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.info
                                          .withValues(alpha: 0.3)),
                                ),
                                child: const Text(
                                  'Your payment proof has been uploaded. '
                                  'Administration will verify your payment soon.',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                            if (status == 'pending') ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.3)),
                                ),
                                child: const Text(
                                  'Your registration is pending admin approval. '
                                  'You will be notified once reviewed.',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // ── Gym schedule / timings ───────────────────────────────
                Text(
                  'Gym Schedule',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),

                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _ScheduleRow(
                          day: 'Mon – Thu',
                          time: '6:00 AM – 10:00 AM',
                          icon: Icons.wb_sunny_outlined,
                          color: AppColors.warning,
                        ),
                        Divider(height: 20),
                        _ScheduleRow(
                          day: 'Mon – Thu',
                          time: '4:00 PM – 8:00 PM',
                          icon: Icons.nights_stay_outlined,
                          color: AppColors.primary,
                        ),
                        Divider(height: 20),
                        _ScheduleRow(
                          day: 'Friday',
                          time: '6:00 AM – 9:00 AM',
                          icon: Icons.wb_sunny_outlined,
                          color: AppColors.warning,
                        ),
                        Divider(height: 20),
                        _ScheduleRow(
                          day: 'Friday',
                          time: '3:00 PM – 7:00 PM',
                          icon: Icons.nights_stay_outlined,
                          color: AppColors.primary,
                        ),
                        Divider(height: 20),
                        _ScheduleRow(
                          day: 'Saturday',
                          time: '7:00 AM – 12:00 PM',
                          icon: Icons.access_time,
                          color: AppColors.accent,
                        ),
                        Divider(height: 20),
                        _ScheduleRow(
                          day: 'Sunday',
                          time: 'Closed',
                          icon: Icons.lock_outline,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.day,
    required this.time,
    required this.icon,
    required this.color,
  });

  final String day;
  final String time;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            day,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          time,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
class _UploadProofButton extends ConsumerStatefulWidget {
  final String registrationId;
  final String? paymentId;
  final String userId;

  const _UploadProofButton({
    required this.registrationId,
    required this.paymentId,
    required this.userId,
  });

  @override
  ConsumerState<_UploadProofButton> createState() => _UploadProofButtonState();
}

class _UploadProofButtonState extends ConsumerState<_UploadProofButton> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    if (widget.paymentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment ID not found. Please try again.')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      Object file;
      if (kIsWeb) {
        file = picked;
      } else {
        file = File(picked.path);
      }

      await ref.read(paymentServiceProvider).uploadFeeChallanProof(
            paymentId: widget.paymentId!,
            userId: widget.userId,
            applicationId: widget.registrationId,
            imageFile: file,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challan uploaded — awaiting admin confirmation'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _uploading ? null : _pickAndUpload,
        icon: _uploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.upload_file),
        label: Text(_uploading ? 'Uploading...' : 'Upload Challan Screenshot'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
