import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/gym_service.dart';
import '../../config/theme.dart';

class GymManagementScreen extends ConsumerWidget {
  const GymManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymService = ref.watch(gymServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym Registrations'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: gymService.getAllRegistrations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final registrations = snapshot.data ?? [];

          if (registrations.isEmpty) {
            return const Center(child: Text('No gym registrations found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: registrations.length,
            itemBuilder: (context, index) {
              final registration = registrations[index];
              final status = (registration['status'] ?? 'pending').toString();
              final registrationDate = registration['registrationDate'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(registration['studentName'] ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(registration['studentEmail'] ?? ''),
                      if (registrationDate != null)
                        Text(
                          'Registered: ${DateFormat('MMM dd, yyyy').format(registrationDate.toDate())}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: status == 'active'
                              ? AppTheme.successColor.withValues(alpha:0.1)
                              : status == 'rejected'
                                  ? AppTheme.errorColor.withValues(alpha:0.1)
                                  : AppTheme.warningColor.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: status == 'active'
                                ? AppTheme.successColor
                                : status == 'rejected'
                                    ? AppTheme.errorColor
                                    : AppTheme.warningColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (status == 'pending') ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.check, color: AppTheme.successColor),
                          onPressed: () => _approveRegistration(
                              context, ref, registration['id'] as String),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.errorColor),
                          onPressed: () => _rejectRegistration(
                              context, ref, registration['id'] as String),
                        ),
                      ],
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _approveRegistration(
      BuildContext context, WidgetRef ref, String registrationId) async {
    try {
      await ref.read(gymServiceProvider).approveRegistration(registrationId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration approved successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _rejectRegistration(
      BuildContext context, WidgetRef ref, String registrationId) async {
    final reasonController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Registration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Reason for rejection (optional):'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(hintText: 'Enter reason...'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(context, false),
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
            onTap: () => Navigator.pop(context, true),
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

    if (result == true) {
      try {
        await ref.read(gymServiceProvider).rejectRegistration(
              registrationId,
              reason: reasonController.text.trim(),
            );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration rejected'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }
}


