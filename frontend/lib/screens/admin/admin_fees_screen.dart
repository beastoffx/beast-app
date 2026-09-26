import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/beast_components.dart';
import '../../models/fee_exam_model.dart';

class AdminFeesScreen extends StatefulWidget {
  const AdminFeesScreen({super.key});

  @override
  State<AdminFeesScreen> createState() => _AdminFeesScreenState();
}

class _AdminFeesScreenState extends State<AdminFeesScreen> {
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchFees();
    });
  }

  void _showRecordPaymentDialog(FeeRecordModel fee) {
    final paidAmountController = TextEditingController(text: fee.amount.toStringAsFixed(0));
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record Payment', style: BeastTypography.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${fee.studentName ?? "N/A"}', style: BeastTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            Text('Invoice: ${fee.feeTitle} • Billed: ₹${fee.amount.toStringAsFixed(0)}', style: BeastTypography.caption),
            const SizedBox(height: 16),
            TextField(
              controller: paidAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Received Amount (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Payment Reference / Note',
                hintText: 'e.g. Bank transfer ref #9042',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: BeastColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BeastColors.dark900,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final amt = double.tryParse(paidAmountController.text.trim()) ?? 0.0;
              final admin = Provider.of<AdminProvider>(context, listen: false);
              final ok = await admin.recordFeePayment(fee.id, amt, notes: notesController.text.trim());
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Payment recorded and receipt generated.' : 'Failed to record payment.')),
                );
              }
            },
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);
    final stats = admin.feeStats;

    return Scaffold(
      backgroundColor: BeastColors.surfaceNeutral,
      appBar: AppBar(
        title: Text('Institutional Fee Ledger', style: BeastTypography.h3),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: BeastColors.dark900),
            onPressed: () => admin.fetchFees(status: _statusFilter),
          ),
        ],
      ),
      body: Column(
        children: [
          // Financial Summary Strip
          if (stats != null) ...[
            Container(
              padding: const EdgeInsets.all(BeastSpacing.lg),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: BeastStatCard(
                      title: 'Total Billed',
                      value: '₹${stats['totalBilled'] ?? 0}',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  const SizedBox(width: BeastSpacing.md),
                  Expanded(
                    child: BeastStatCard(
                      title: 'Collected',
                      value: '₹${stats['totalCollected'] ?? 0}',
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: BeastSpacing.md),
                  Expanded(
                    child: BeastStatCard(
                      title: 'Outstanding',
                      value: '₹${stats['totalOutstanding'] ?? 0}',
                      icon: Icons.pending_actions_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: BeastColors.borderSubtle),
          ],

          // Filter bar
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: BeastSpacing.lg, vertical: BeastSpacing.sm),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Invoices'),
                  selected: _statusFilter == null,
                  selectedColor: BeastColors.peach200,
                  backgroundColor: BeastColors.neutral100,
                  onSelected: (_) {
                    setState(() => _statusFilter = null);
                    admin.fetchFees();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Pending'),
                  selected: _statusFilter == 'pending',
                  selectedColor: BeastColors.peach200,
                  backgroundColor: BeastColors.neutral100,
                  onSelected: (_) {
                    setState(() => _statusFilter = 'pending');
                    admin.fetchFees(status: 'pending');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Paid'),
                  selected: _statusFilter == 'paid',
                  selectedColor: BeastColors.peach200,
                  backgroundColor: BeastColors.neutral100,
                  onSelected: (_) {
                    setState(() => _statusFilter = 'paid');
                    admin.fetchFees(status: 'paid');
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: BeastColors.borderSubtle),

          Expanded(
            child: admin.isLoading
                ? const Center(child: BeastLoadingState(message: 'Loading fee ledger...'))
                : admin.fees.isEmpty
                    ? const BeastEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Fee Records',
                        subtitle: 'No fee invoices match the selected criteria.',
                      )
                    : RefreshIndicator(
                        onRefresh: () => admin.fetchFees(status: _statusFilter),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(BeastSpacing.lg),
                          itemCount: admin.fees.length,
                          separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                          itemBuilder: (ctx, i) {
                            final f = admin.fees[i];
                            return BeastCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          f.studentName ?? 'Student',
                                          style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      BeastStatusBadge(status: f.isPaid ? 'PAID' : 'PENDING'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${f.feeTitle} • ID: ${f.studentIdNumber ?? ""} • Due: ${f.dueDate}',
                                    style: BeastTypography.caption,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '₹${f.amount.toStringAsFixed(0)} (Paid: ₹${f.paidAmount.toStringAsFixed(0)})',
                                        style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w800, color: BeastColors.dark900),
                                      ),
                                      if (!f.isPaid)
                                        ElevatedButton(
                                          onPressed: () => _showRecordPaymentDialog(f),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: BeastColors.dark900,
                                            foregroundColor: Colors.white,
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          child: const Text('Record Payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        )
                                      else if (f.receiptReference != null)
                                        Text(
                                          f.receiptReference!,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BeastColors.success),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
