import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/mess_service.dart';
import '../services/payment_service.dart';
import '../models/mess_model.dart';
import '../models/mess_bill_model.dart';
import '../models/payment_model.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../platform_io.dart';

class MessScreen extends ConsumerStatefulWidget {
  const MessScreen({super.key});

  @override
  ConsumerState<MessScreen> createState() => _MessScreenState();
}

class _MessScreenState extends ConsumerState<MessScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mess Schedule')),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            ColoredBox(
              color: AppColors.primary,
              child: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: AppColors.accent,
                indicatorWeight: 3,
                labelStyle: TextStyle(fontWeight: FontWeight.w700),
                tabs: [Tab(text: 'Schedule'), Tab(text: 'My Bill')],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // ── Schedule Tab ─────────────────────────────────────────
                  StreamBuilder<List<MessMenu>>(
                    stream: ref
                        .watch(messServiceProvider)
                        .getCurrentWeekMenu(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        final err = snapshot.error.toString();
                        final isPermission =
                            err.contains('permission-denied') ||
                                err.contains('insufficient permissions');
                        return _EmptyState(
                          icon: isPermission
                              ? Icons.lock_outline_rounded
                              : Icons.restaurant_menu_outlined,
                          title: isPermission
                              ? 'Access Restricted'
                              : 'Schedule Unavailable',
                          subtitle: isPermission
                              ? 'Admin needs to update Firestore security rules.'
                              : err,
                          iconColor: isPermission
                              ? AppColors.warning
                              : AppColors.error,
                        );
                      }
                      final menus = snapshot.data ?? [];
                      if (menus.isEmpty) {
                        return const _EmptyState(
                          icon: Icons.restaurant_menu_outlined,
                          title: 'No Menu This Week',
                          subtitle:
                              'The mess schedule has not been posted yet.',
                        );
                      }
                      menus.sort((a, b) => a.date.compareTo(b.date));
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: menus.length,
                        itemBuilder: (context, index) {
                          final menu = menus[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE, MMM d')
                                        .format(menu.date),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  _DayMealSection(
                                      type: MealType.breakfast,
                                      items: menu.meals[
                                              MealType.breakfast] ??
                                          []),
                                  _DayMealSection(
                                      type: MealType.lunch,
                                      items:
                                          menu.meals[MealType.lunch] ??
                                              []),
                                  _DayMealSection(
                                      type: MealType.dinner,
                                      items:
                                          menu.meals[MealType.dinner] ??
                                              []),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // ── My Bill Tab ──────────────────────────────────────────
                  Consumer(
                    builder: (context, ref, _) {
                      final user =
                          ref.watch(currentUserProvider).value;
                      if (user == null) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      return _MessBillingTab(userId: user.uid);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── My Bill Tab ───────────────────────────────────────────────────────────────

class _MessBillingTab extends ConsumerStatefulWidget {
  const _MessBillingTab({required this.userId});
  final String userId;

  @override
  ConsumerState<_MessBillingTab> createState() => _MessBillingTabState();
}

class _MessBillingTabState extends ConsumerState<_MessBillingTab> {
  final _amountCtrl = TextEditingController();
  XFile? _challanImage;
  bool _isUploading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _challanImage = file);
  }

  Future<void> _submitPayment(double outstanding) async {
    final txt = _amountCtrl.text.trim();
    if (txt.isEmpty) return _snack('Enter payment amount.', AppColors.error);
    final amt = double.tryParse(txt);
    if (amt == null || amt <= 0)
      return _snack('Enter a valid amount.', AppColors.error);
    if (amt > outstanding)
      return _snack(
          'Amount cannot exceed outstanding (PKR ${outstanding.toStringAsFixed(0)}).',
          AppColors.error);
    if (_challanImage == null)
      return _snack('Upload your bank challan image.', AppColors.error);

    setState(() => _isUploading = true);
    try {
      final svc = PaymentService();
      final pid = await svc.createPayment(PaymentModel(
        id: '',
        userId: widget.userId,
        amount: amt,
        type: PaymentType.messFee,
        status: PaymentStatus.pending,
        description: 'Mess Bill Payment',
        dueDate: DateTime.now(),
        metadata: {'studentId': widget.userId},
      ));
      await svc.uploadFeeChallanProof(
        paymentId: pid,
        userId: widget.userId,
        applicationId: widget.userId,
        imageFile: _challanImage,
        paidAmount: amt,
      );
      setState(() {
        _challanImage = null;
        _amountCtrl.clear();
      });
      _snack('Payment submitted! Admin will verify and update your bill.',
          AppColors.success);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), AppColors.error);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MessBillModel?>(
      stream: ref.watch(messServiceProvider).getStudentBill(widget.userId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return const _EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Bill Unavailable',
            subtitle:
                'Contact admin to update Firestore security rules.',
            iconColor: AppColors.warning,
          );
        }

        final bill = snap.data;
        final outstanding = bill?.amount ?? 0.0;

        // Pre-fill amount field with outstanding total if empty
        if (_amountCtrl.text.isEmpty && outstanding > 0) {
          _amountCtrl.text = outstanding.toStringAsFixed(0);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Bill Summary ─────────────────────────────────────────
              _BillSummaryCard(
                outstanding: outstanding,
                lastUpdated: bill != null
                    ? DateFormat('MMM d, y').format(bill.lastUpdated)
                    : null,
                userId: widget.userId,
              ),

              // ── Pay Bill Form (only when amount > 0) ─────────────────
              if (outstanding > 0) ...[
                const SizedBox(height: 20),
                _PayBillCard(
                  outstanding: outstanding,
                  amountCtrl: _amountCtrl,
                  challanImage: _challanImage,
                  isUploading: _isUploading,
                  onPickImage: _pickImage,
                  onRemoveImage: () =>
                      setState(() => _challanImage = null),
                  onSubmit: () => _submitPayment(outstanding),
                ),
              ],

              const SizedBox(height: 24),

              // ── Payment History ──────────────────────────────────────
              Text('Payment History',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _PaymentHistory(userId: widget.userId),
            ],
          ),
        );
      },
    );
  }
}

// ── Bill Summary Card ─────────────────────────────────────────────────────────

class _BillSummaryCard extends StatelessWidget {
  const _BillSummaryCard({
    required this.outstanding,
    required this.lastUpdated,
    required this.userId,
  });
  final double outstanding;
  final String? lastUpdated;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feePayments')
          .where('userId', isEqualTo: userId)
          .where('paymentType',
              isEqualTo: PaymentType.messFee.toString())
          .where('adminAccepted', isEqualTo: false)
          .snapshots(),
      builder: (context, snap) {
        // Sum pending (challan uploaded, not yet approved)
        double pendingAmt = 0;
        for (final doc in snap.data?.docs ?? []) {
          final d = doc.data() as Map<String, dynamic>;
          if ((d['proofUrl'] ?? '').toString().isNotEmpty) {
            pendingAmt += (d['amount'] ?? 0).toDouble();
          }
        }
        final remaining =
            (outstanding - pendingAmt).clamp(0.0, outstanding);

        final isCleared = outstanding <= 0;
        final colors = isCleared
            ? [Colors.green.shade700, Colors.green.shade400]
            : [Colors.red.shade700, Colors.red.shade400];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: colors.first.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.receipt_long, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text('Mess Bill Summary',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ]),
              const SizedBox(height: 14),
              const Divider(color: Colors.white30, height: 1),
              const SizedBox(height: 12),

              _row('Total Outstanding',
                  'PKR ${outstanding.toStringAsFixed(0)}', Colors.white),

              if (pendingAmt > 0) ...[
                const SizedBox(height: 8),
                _row(
                    'Paid (Awaiting Verification)',
                    '- PKR ${pendingAmt.toStringAsFixed(0)}',
                    Colors.yellow.shade200),
                const SizedBox(height: 8),
                const Divider(color: Colors.white30, height: 1),
                const SizedBox(height: 8),
                _row('Remaining After Verification',
                    'PKR ${remaining.toStringAsFixed(0)}', Colors.white),
              ],

              if (lastUpdated != null) ...[
                const SizedBox(height: 10),
                Text('Last updated: $lastUpdated',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ],

              if (isCleared) ...[
                const SizedBox(height: 10),
                const Row(children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('All dues cleared',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value, Color valColor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13)),
            Text(value,
                style: TextStyle(
                    color: valColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ],
        ),
      );
}

// ── Pay Bill Card ─────────────────────────────────────────────────────────────

class _PayBillCard extends StatelessWidget {
  const _PayBillCard({
    required this.outstanding,
    required this.amountCtrl,
    required this.challanImage,
    required this.isUploading,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onSubmit,
  });

  final double outstanding;
  final TextEditingController amountCtrl;
  final XFile? challanImage;
  final bool isUploading;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Row(children: [
            Icon(Icons.payments_rounded,
                color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Pay Mess Bill',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.primary)),
          ]),
          const SizedBox(height: 4),
          Text(
            'Enter amount (full or partial) and upload bank challan.',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // Amount field
          TextFormField(
            controller: amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Payment Amount',
              hintText: 'Max: PKR ${outstanding.toStringAsFixed(0)}',
              prefixIcon: const Icon(Icons.currency_rupee),
              suffixText: 'PKR',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 14),

          // Challan image upload
          const Text('Bank Challan / Payment Proof',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),

          GestureDetector(
            onTap: challanImage == null ? onPickImage : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: challanImage != null ? 200 : 110,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.5),
              ),
              child: challanImage == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file_rounded,
                            size: 40, color: AppColors.primary),
                        SizedBox(height: 6),
                        Text('Tap to upload challan',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        Text('JPG / PNG',
                            style: TextStyle(
                                color: AppColors.textDisabled,
                                fontSize: 11)),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: FutureBuilder<Uint8List>(
                            future: challanImage!.readAsBytes(),
                            builder: (ctx, s) => s.hasData
                                ? Image.memory(s.data!,
                                    fit: BoxFit.cover)
                                : const Center(
                                    child: CircularProgressIndicator()),
                          ),
                        ),
                        // Remove button
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: onRemoveImage,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                        // Change button
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: GestureDetector(
                            onTap: onPickImage,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh,
                                      color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text('Change',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isUploading ? null : onSubmit,
              icon: isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: Text(
                isUploading ? 'Submitting...' : 'Submit Payment',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Admin will verify your payment and reduce your outstanding bill.',
            style:
                TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Payment History ───────────────────────────────────────────────────────────

class _PaymentHistory extends StatelessWidget {
  const _PaymentHistory({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('feePayments')
          .where('userId', isEqualTo: userId)
          .where('paymentType',
              isEqualTo: PaymentType.messFee.toString())
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || (snap.data?.docs ?? []).isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.18)),
            ),
            child: const Center(
              child: Text('No payment history yet.',
                  style:
                      TextStyle(color: AppColors.textSecondary)),
            ),
          );
        }

        final docs = List<QueryDocumentSnapshot>.from(snap.data!.docs)
          ..sort((a, b) {
            final aT = (a.data() as Map)['createdAt'] as Timestamp?;
            final bT = (b.data() as Map)['createdAt'] as Timestamp?;
            if (aT == null) return 1;
            if (bT == null) return -1;
            return bT.compareTo(aT);
          });

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final amount = (d['amount'] ?? 0).toDouble();
            final accepted = d['adminAccepted'] as bool? ?? false;
            final hasProof =
                (d['proofUrl'] ?? '').toString().isNotEmpty;
            final date =
                (d['createdAt'] as Timestamp?)?.toDate();
            final dateStr = date != null
                ? DateFormat('MMM d, y • h:mm a').format(date)
                : '—';

            late Color color;
            late String label;
            late IconData icon;
            if (accepted) {
              color = AppColors.success;
              label = 'Approved';
              icon = Icons.check_circle_rounded;
            } else if (hasProof) {
              color = AppColors.warning;
              label = 'Pending Verification';
              icon = Icons.hourglass_empty_rounded;
            } else {
              color = AppColors.textDisabled;
              label = 'Challan Not Uploaded';
              icon = Icons.upload_file_outlined;
            }

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mess Bill Payment',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(20)),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: color)),
                        ),
                      ],
                    ),
                  ),
                  Text('PKR ${amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: iconColor ?? AppColors.textDisabled),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Schedule Day Meal Section ─────────────────────────────────────────────────

class _DayMealSection extends StatelessWidget {
  const _DayMealSection({required this.type, required this.items});
  final MealType type;
  final List<MessMenuItem> items;

  String get _title {
    switch (type) {
      case MealType.breakfast: return 'Breakfast';
      case MealType.lunch:     return 'Lunch';
      case MealType.dinner:    return 'Dinner';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(item.name,
                          style: Theme.of(context).textTheme.bodyMedium)),
                  Text(
                    'Rs. ${item.price.toStringAsFixed(0)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
