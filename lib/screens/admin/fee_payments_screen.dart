import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/hostel_service.dart';
import '../../services/mess_service.dart';
import '../../services/gym_service.dart';
import '../../services/payment_service.dart';
import '../../models/payment_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FeePaymentsScreen extends ConsumerStatefulWidget {
  const FeePaymentsScreen({super.key});

  @override
  ConsumerState<FeePaymentsScreen> createState() => _FeePaymentsScreenState();
}

class _SummaryItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _FeePaymentsScreenState extends ConsumerState<FeePaymentsScreen> {
  final Set<String> _processing = {};
  String _filterStatus = 'all'; // 'all', 'pending', 'accepted'
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _dateFormatter = DateFormat('MMM d, y h:mm a');

  String _formatDate(DateTime date) => _dateFormatter.format(date);

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
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (context, url, error) => const Center(
                child: Icon(Icons.error_outline, size: 48),
              ),
            ),
            Positioned(
              right: -12,
              top: -12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
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
        title: const Text('Fee Payments'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by User ID...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter chips
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _filterStatus == 'all',
                    onSelected: (selected) =>
                        setState(() => _filterStatus = 'all'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Pending'),
                    selected: _filterStatus == 'pending',
                    onSelected: (selected) =>
                        setState(() => _filterStatus = 'pending'),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Accepted'),
                    selected: _filterStatus == 'accepted',
                    onSelected: (selected) =>
                        setState(() => _filterStatus = 'accepted'),
                  ),
                ],
              ),
            ),
            // Summary card
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('feePayments')
                  .orderBy('createdAt', descending: true)
                  .snapshots()
                  .map((s) => s.docs.map((d) {
                        final m = Map<String, dynamic>.from(d.data());
                        m['id'] = d.id;
                        return m;
                      }).toList()),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();

                final items = snapshot.data ?? [];
                final totalPayments = items.length;
                final acceptedPayments =
                    items.where((item) => item['adminAccepted'] == true).length;
                final pendingPayments = totalPayments - acceptedPayments;
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          title: 'Total',
                          value: totalPayments.toString(),
                          icon: Icons.receipt_long,
                        ),
                        _SummaryItem(
                          title: 'Pending',
                          value: pendingPayments.toString(),
                          icon: Icons.pending_actions,
                          color: Colors.orange,
                        ),
                        _SummaryItem(
                          title: 'Accepted',
                          value: acceptedPayments.toString(),
                          icon: Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Payment list
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('feePayments')
                    .orderBy('createdAt', descending: true)
                    .snapshots()
                    .map((s) => s.docs.map((d) {
                          final m = Map<String, dynamic>.from(d.data());
                          m['id'] = d.id;
                          return m;
                        }).toList()),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  var items = snapshot.data ?? [];

                  // Apply filters
                  if (_filterStatus != 'all') {
                    items = items
                        .where((item) => _filterStatus == 'accepted'
                            ? item['adminAccepted'] == true
                            : item['adminAccepted'] != true)
                        .toList();
                  }

                  // Apply search
                  if (_searchQuery.isNotEmpty) {
                    items = items
                        .where((item) =>
                            (item['userId'] as String?)
                                ?.toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ??
                            false)
                        .toList();
                  }

                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty
                                ? Icons.search_off
                                : Icons.receipt_long,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No payments matching "$_searchQuery"'
                                : _filterStatus != 'all'
                                    ? 'No $_filterStatus payments'
                                    : 'No fee payments',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final id = item['id'] as String;
                      final userId = item['userId'] ?? '';
                      final applicationId = item['applicationId'];
                      final amount = item['amount'];
                      final paymentType = item['paymentType'] ?? PaymentType.hostelFee.toString();
                      final adminAccepted = item['adminAccepted'] ?? false;
                      final processing = _processing.contains(id);

                      final proofUrl = item['proofUrl'] as String?;

                      final createdAt =
                          (item['createdAt'] as Timestamp?)?.toDate();
                      final updatedAt =
                          (item['updatedAt'] as Timestamp?)?.toDate();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Proof Image Thumbnail
                              if (proofUrl != null)
                                GestureDetector(
                                  onTap: () =>
                                      _showFullImage(context, proofUrl),
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    margin: const EdgeInsets.only(right: 16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: proofUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            const Center(
                                          child: Icon(Icons.error_outline),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Payment Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FutureBuilder<DocumentSnapshot>(
                                      future: FirebaseFirestore.instance.collection('profiles').doc(userId).get(),
                                      builder: (context, profileSnap) {
                                        String displayStr = 'User: $userId';
                                        if (profileSnap.hasData && profileSnap.data!.exists) {
                                          final data = profileSnap.data!.data() as Map<String, dynamic>?;
                                          if (data != null) {
                                            final name = data['name'] ?? 'Unknown';
                                            final roll = data['arnRollNumber'] ?? data['rollNumber'] ?? 'N/A';
                                            displayStr = '$name - $roll';
                                          }
                                        } else if (profileSnap.connectionState == ConnectionState.waiting) {
                                          displayStr = 'Loading user...';
                                        }
                                        return Text(
                                          displayStr,
                                          style: Theme.of(context).textTheme.titleMedium,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 4),
                                    if (applicationId != null && applicationId.toString().isNotEmpty)
                                      Text('Application: $applicationId'),
                                    Text('Type: ${paymentType.split('.').last}'),
                                    if (amount != null)
                                      Text(
                                        'Amount (ref): Rs. ${amount.toString()}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    if (createdAt != null)
                                      Text(
                                        'Submitted: ${_formatDate(createdAt)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    if (adminAccepted && updatedAt != null)
                                      Text(
                                        'Accepted: ${_formatDate(updatedAt)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    Text(
                                      'Status: ${adminAccepted ? 'Accepted' : 'Pending'}',
                                      style: TextStyle(
                                        color: adminAccepted
                                            ? Colors.green
                                            : Colors.orange,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (!adminAccepted) ...[
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: processing
                                            ? null
                                            : () async {
                                                setState(() => _processing.add(id));
                                                try {
                                                  // 1) Mark payment in DB as verified
                                                  final paymentId = item['paymentId'] as String?;
                                                  if (paymentId != null) {
                                                    await ref
                                                        .read(paymentServiceProvider)
                                                        .updatePaymentStatus(
                                                            paymentId,
                                                            PaymentStatus.completed,
                                                            null);
                                                  }
                                                  
                                                  // 2) Handle specific type logic
                                                  if (paymentType == PaymentType.hostelFee.toString()) {
                                                    if (applicationId != null) {
                                                      await ref
                                                          .read(hostelServiceProvider)
                                                          .confirmFeePayment(
                                                              applicationId,
                                                              feePaymentId: id);
                                                    } else {
                                                      throw Exception('No application linked for Hostel Fee');
                                                    }
                                                  } else if (paymentType == PaymentType.messFee.toString()) {
                                                    await ref
                                                        .read(messServiceProvider)
                                                        .processPayment(userId, (amount as num).toDouble());
                                                    
                                                    // Also update the feePayments doc directly since mess reset doesn't touch feePayments
                                                    await FirebaseFirestore.instance
                                                        .collection('feePayments')
                                                        .doc(id)
                                                        .update({
                                                      'adminAccepted': true,
                                                      'updatedAt': Timestamp.fromDate(DateTime.now()),
                                                    });
                                                  } else if (paymentType == PaymentType.gymFee.toString()) {
                                                    if (applicationId != null) {
                                                      await ref
                                                          .read(gymServiceProvider)
                                                          .approveRegistration(applicationId);
                                                      
                                                      await FirebaseFirestore.instance
                                                          .collection('feePayments')
                                                          .doc(id)
                                                          .update({
                                                        'adminAccepted': true,
                                                        'updatedAt': Timestamp.fromDate(DateTime.now()),
                                                      });
                                                    } else {
                                                      throw Exception('No registration ID linked for Gym Fee');
                                                    }
                                                  } else {
                                                    // Catch-all
                                                    await FirebaseFirestore.instance
                                                        .collection('feePayments')
                                                        .doc(id)
                                                        .update({
                                                      'adminAccepted': true,
                                                      'updatedAt': Timestamp.fromDate(DateTime.now()),
                                                    });
                                                  }

                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(const SnackBar(
                                                            content: Text('Payment accepted')));
                                                  }
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(SnackBar(
                                                            content: Text('Error: $e')));
                                                  }
                                                } finally {
                                                  setState(() => _processing.remove(id));
                                                }
                                              },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: processing
                                                ? Theme.of(context).primaryColor.withValues(alpha: 0.5)
                                                : Theme.of(context).primaryColor,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (processing)
                                                const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              else
                                                const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Accept Payment',
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
            ),
          ],
        ),
      ),
    );
  }
}
