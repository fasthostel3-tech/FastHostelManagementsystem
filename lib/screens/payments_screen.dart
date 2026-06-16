import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';
import '../providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:url_launcher/url_launcher.dart';
import '../platform_io.dart';
import 'package:http/http.dart' as http;

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  @override
  Widget build(BuildContext context) {
    return ref.watch(currentUserProvider).when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(
              child: Text('Please login to view payments'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Due Payments'),
          ),
          body: _DuePaymentsTab(userId: user.uid),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}

class _DuePaymentsTab extends ConsumerWidget {
  final String userId;

  const _DuePaymentsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<PaymentModel>>(
      stream: ref.watch(paymentServiceProvider).getDuePayments(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final payments = snapshot.data ?? [];

        if (payments.isEmpty) {
          return const Center(child: Text('No due payments'));
        }

        return ListView.builder(
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            return PaymentCard(payment: payment);
          },
        );
      },
    );
  }
}

Future<void> _viewChallan(BuildContext context, String challanUrl) async {
  try {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Download challan content
    final response = await http.get(Uri.parse(challanUrl));

    if (!context.mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    if (response.statusCode == 200) {
      final challanText = response.body;

      // Show challan in dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Fee Challan'),
            content: SingleChildScrollView(
              child: SelectableText(
                challanText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  // Try to open in browser as fallback
                  final url = Uri.parse(challanUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Open in Browser',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // If download fails, try to open URL directly
      final url = Uri.parse(challanUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Could not load challan. Please try again later.')),
          );
        }
      }
    }
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop(); // Close loading dialog if still open

    // Try to open URL directly as fallback
    try {
      final url = Uri.parse(challanUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading challan: $e')),
          );
        }
      }
    } catch (e2) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening challan: $e2')),
        );
      }
    }
  }
}

class PaymentCard extends StatelessWidget {
  final PaymentModel payment;

  const PaymentCard({super.key, required this.payment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat =
        NumberFormat.currency(locale: 'en_US', symbol: 'Rs. ');

    Color statusColor;
    switch (payment.status) {
      case PaymentStatus.completed:
        statusColor = Colors.green;
        break;
      case PaymentStatus.pending:
        statusColor = Colors.orange;
        break;
      case PaymentStatus.failed:
        statusColor = Colors.red;
        break;
      case PaymentStatus.refunded:
        statusColor = Colors.blue;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          payment.description,
          style: theme.textTheme.titleMedium,
        ),

        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            payment.status.toString().split('.').last,
            style: theme.textTheme.bodySmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () {},
        // Show contextual actions for hostel fee payments
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Due Date: ${DateFormat('MMM dd, yyyy').format(payment.dueDate)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              currencyFormat.format(payment.amount),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if ((payment.type == PaymentType.hostelFee ||
                    payment.type == PaymentType.messFee ||
                    payment.type == PaymentType.gymFee) &&
                payment.bankName != null &&
                payment.accountNumber != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Details:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bank: ${payment.bankName}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      'Account No: ${payment.accountNumber}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (payment.accountTitle != null)
                      Text(
                        'Account Title: ${payment.accountTitle}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
            if (payment.challanUrl != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  await _viewChallan(context, payment.challanUrl!);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'View Challan',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            if ((payment.type == PaymentType.hostelFee ||
                    payment.type == PaymentType.messFee ||
                    payment.type == PaymentType.gymFee) &&
                payment.status == PaymentStatus.pending) ...[
              _UploadChallanButton(payment: payment),
            ],
          ],
        ),
      ),
    );
  }
}

class _UploadChallanButton extends ConsumerStatefulWidget {
  final PaymentModel payment;

  const _UploadChallanButton({required this.payment});

  @override
  ConsumerState<_UploadChallanButton> createState() =>
      _UploadChallanButtonState();
}

class _UploadChallanButtonState extends ConsumerState<_UploadChallanButton> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    double? amountOverride;
    if (widget.payment.type == PaymentType.messFee) {
      final controller = TextEditingController(text: widget.payment.amount.toStringAsFixed(0));
      amountOverride = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Payment Amount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the actual amount you have paid as shown on your challan.'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Paid Amount (Rs.)',
                  border: OutlineInputBorder(),
                  prefixText: 'Rs. ',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(controller.text);
                if (val != null && val > 0) {
                  Navigator.pop(context, val);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                }
              },
              child: const Text('Confirm & Upload'),
            ),
          ],
        ),
      );
      
      if (amountOverride == null) return; // User cancelled
    }

    setState(() => _uploading = true);
    try {
      Object file;
      if (kIsWeb) {
        file = picked; // XFile on web
      } else {
        file = File(picked.path);
      }
      final paymentId = widget.payment.id;
      final userId = widget.payment.userId;
      final applicationId = widget.payment.metadata?.containsKey('applicationId') == true
          ? widget.payment.metadata!['applicationId'] as String?
          : null;

      await ref.read(paymentServiceProvider).uploadFeeChallanProof(
            paymentId: paymentId,
            userId: userId,
            applicationId: applicationId,
            imageFile: file,
            paidAmount: amountOverride,
          );

      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Challan uploaded — awaiting admin confirmation')));
      }
    } catch (e) {
      debugPrint('[PaymentsScreen] Challan upload failed: $e');
      if (!mounted) return;
      if (mounted) {
        // Extract clean error message
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring('Exception: '.length);
        }
        // Strip nested Exception prefixes
        while (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring('Exception: '.length);
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload challan: $errorMsg')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _uploading ? null : _pickAndUpload,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _uploading
              ? Theme.of(context).primaryColor.withOpacity(0.5)
              : Theme.of(context).primaryColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_uploading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.upload_file, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              _uploading ? 'Uploading...' : 'Upload Challan',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
