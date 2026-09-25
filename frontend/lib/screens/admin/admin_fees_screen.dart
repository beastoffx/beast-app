import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_card.dart';
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
        title: Text('Record Payment: ${fee.studentName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice: ${fee.feeTitle} • Billed: ₹${fee.amount}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: paidAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Received Amount (₹)', prefixText: '₹ '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Payment Note / Method', hintText: 'e.g. Bank transfer ref #9042'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
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
      appBar: AppBar(
        title: const Text('Institutional Fee Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => admin.fetchFees(status: _statusFilter),
          ),
        ],
      ),
      body: Column(
        children: [
          // Financial Summary Strip
          if (stats != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BILLED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                        Text('₹${stats['totalBilled'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('COLLECTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success)),
                        Text('₹${stats['totalCollected'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.success)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('OUTSTANDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.error)),
                        Text('₹${stats['totalOutstanding'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],

          // Filter bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _statusFilter == null,
                  onSelected: (_) {
                    setState(() => _statusFilter = null);
                    admin.fetchFees();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Pending'),
                  selected: _statusFilter == 'pending',
                  onSelected: (_) {
                    setState(() => _statusFilter = 'pending');
                    admin.fetchFees(status: 'pending');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Paid'),
                  selected: _statusFilter == 'paid',
                  onSelected: (_) {
                    setState(() => _statusFilter = 'paid');
                    admin.fetchFees(status: 'paid');
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: admin.isLoading
                ? const Center(child: CircularProgressIndicator())
                : admin.fees.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Fee Records',
                        description: 'No fee invoices match the selected filter.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: admin.fees.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final f = admin.fees[i];
                          return AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      f.studentName ?? 'Student',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                    if (f.isPaid)
                                      StatusBadge.paid()
                                    else
                                      StatusBadge.pending(),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${f.feeTitle} • ID: ${f.studentIdNumber ?? ""} • Due: ${f.dueDate}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '₹${f.amount.toStringAsFixed(0)} (Paid: ₹${f.paidAmount.toStringAsFixed(0)})',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    if (!f.isPaid)
                                      ElevatedButton(
                                        onPressed: () => _showRecordPaymentDialog(f),
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(110, 32),
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                        ),
                                        child: const Text('Record Payment', style: TextStyle(fontSize: 11)),
                                      )
                                    else if (f.receiptReference != null)
                                      Text(
                                        f.receiptReference!,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
