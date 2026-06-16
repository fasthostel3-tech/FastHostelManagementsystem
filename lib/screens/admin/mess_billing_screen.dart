import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/mess_service.dart';
import '../../models/mess_bill_model.dart';
import '../../models/payment_model.dart';
import '../../config/theme.dart';

class MessBillingScreen extends ConsumerStatefulWidget {
  const MessBillingScreen({super.key});

  @override
  ConsumerState<MessBillingScreen> createState() => _MessBillingScreenState();
}

class _MessBillingScreenState extends ConsumerState<MessBillingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final _dateFormatter = DateFormat('MMM d, y');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) =>
                  const Center(child: Icon(Icons.error_outline, size: 48)),
            ),
            Positioned(
              right: -12,
              top: -12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess Billing'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Name or Roll No',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Bills List
          Expanded(
            child: StreamBuilder<List<MessBillModel>>(
              stream: ref.watch(messServiceProvider).getAllBills(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final bills = snapshot.data ?? [];

                final filteredBills = bills.where((bill) {
                  return bill.studentName
                          .toLowerCase()
                          .contains(_searchQuery) ||
                      bill.rollNumber.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filteredBills.isEmpty) {
                  return const Center(child: Text('No bills found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredBills.length,
                  itemBuilder: (context, index) {
                    final bill = filteredBills[index];
                    return _MessBillCard(
                      bill: bill,
                      dateFormatter: _dateFormatter,
                      onShowImage: _showFullImage,
                      onApprove: () => _confirmPayment(context, ref, bill),
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

  Future<void> _confirmPayment(
      BuildContext context, WidgetRef ref, MessBillModel bill) async {
    // 1. Check for pending fee payment submission to get suggested amount
    double suggestedAmount = bill.amount;
    String? pendingPaymentId;
    
    try {
      final snap = await FirebaseFirestore.instance
          .collection('feePayments')
          .where('userId', isEqualTo: bill.studentId)
          .where('paymentType', isEqualTo: PaymentType.messFee.toString())
          .where('adminAccepted', isEqualTo: false)
          .limit(1)
          .get();
      
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        suggestedAmount = (data['amount'] as num?)?.toDouble() ?? bill.amount;
        pendingPaymentId = snap.docs.first.id;
      }
    } catch (e) {
      debugPrint('Error fetching pending payment: $e');
    }

    final amountController = TextEditingController(text: suggestedAmount.toStringAsFixed(0));
    
    final confirmed = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Approving payment for ${bill.studentName}.'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount Paid (PKR)',
                border: OutlineInputBorder(),
                prefixText: 'Rs. ',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Remaining after this: PKR ${(bill.amount - suggestedAmount).clamp(0, double.infinity).toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
              final val = double.tryParse(amountController.text);
              if (val != null && val > 0) {
                Navigator.pop(context, val);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != null) {
      try {
        await ref.read(messServiceProvider).processPayment(bill.id, confirmed);
        
        // Also update any pending feePayments records for this student
        // We'll mark them as accepted if they match the user we just processed
        final pendingPayments = await FirebaseFirestore.instance
            .collection('feePayments')
            .where('userId', isEqualTo: bill.studentId)
            .where('paymentType', isEqualTo: PaymentType.messFee.toString())
            .where('adminAccepted', isEqualTo: false)
            .get();
            
        for (final doc in pendingPayments.docs) {
          await doc.reference.update({
            'adminAccepted': true,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment of Rs. ${confirmed.toStringAsFixed(0)} approved')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

// ── Per-bill card with payment screenshot ────────────────────────────────────

class _MessBillCard extends ConsumerWidget {
  const _MessBillCard({
    required this.bill,
    required this.dateFormatter,
    required this.onShowImage,
    required this.onApprove,
  });

  final MessBillModel bill;
  final DateFormat dateFormatter;
  final void Function(BuildContext, String) onShowImage;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Student Info Row ─────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    bill.studentName.isNotEmpty
                        ? bill.studentName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.studentName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        bill.rollNumber.isNotEmpty
                            ? bill.rollNumber
                            : 'No Roll No',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PKR ${bill.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: bill.amount > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: bill.amount > 0
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        bill.amount > 0 ? 'Unpaid' : 'Paid',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              bill.amount > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Divider(height: 20),

            // ── Payment Screenshot from feePayments ──────────────────────
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('feePayments')
                  .where('userId', isEqualTo: bill.studentId)
                  .where('paymentType',
                      isEqualTo: PaymentType.messFee.toString())
                  .where('adminAccepted', isEqualTo: false)
                  .limit(1)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  // No pending payment submission
                  return Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.image_not_supported_outlined,
                              size: 16, color: Colors.grey),
                          SizedBox(width: 6),
                          Text(
                            'No payment screenshot submitted yet',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      if (bill.amount > 0) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: onApprove,
                            icon: const Icon(Icons.check_circle_outline,
                                size: 18),
                            label: const Text('Approve Payment'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                }

                final paymentData = snap.data!.docs.first.data()
                    as Map<String, dynamic>;
                final proofUrl = paymentData['proofUrl'] as String?;
                final createdAt =
                    (paymentData['createdAt'] as Timestamp?)?.toDate();
                final submittedDate = createdAt != null
                    ? dateFormatter.format(createdAt)
                    : 'Unknown';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Screenshot label
                    Row(
                      children: [
                        const Icon(Icons.receipt,
                            size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          'Payment Screenshot — Submitted $submittedDate',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Screenshot thumbnail
                    if (proofUrl != null)
                      GestureDetector(
                        onTap: () => onShowImage(context, proofUrl),
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: proofUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) =>
                                  const Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image,
                                        color: Colors.grey, size: 32),
                                    SizedBox(height: 4),
                                    Text('Image unavailable',
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: const Text(
                          'Screenshot not yet uploaded',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 4),
                    const Text(
                      'Tap screenshot to view full size',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),

                    const SizedBox(height: 12),

                    // Approve button
                    if (bill.amount > 0)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onApprove,
                          icon: const Icon(Icons.check_circle_outline,
                              size: 18),
                          label: const Text('Approve Payment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // ── Already paid ─────────────────────────────────────────────
            if (bill.amount <= 0)
              const Align(
                alignment: Alignment.centerRight,
                child: Chip(
                  label: Text('Paid'),
                  backgroundColor: Colors.green,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
