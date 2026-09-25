import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/student_provider.dart';
import '../../widgets/app_card.dart';

class StudentFeesScreen extends StatefulWidget {
  const StudentFeesScreen({super.key});

  @override
  State<StudentFeesScreen> createState() => _StudentFeesScreenState();
}

class _StudentFeesScreenState extends State<StudentFeesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentProvider>(context, listen: false).fetchFees();
    });
  }

  @override
  Widget build(BuildContext context) {
    final student = Provider.of<StudentProvider>(context);
    final summary = student.feeSummary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Ledger & Receipts'),
      ),
      body: student.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => student.fetchFees(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Financial Summary Card
                    if (summary != null) ...[
                      AppCard(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('TOTAL BILLED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                                  const SizedBox(height: 4),
                                  Text('₹${summary['totalDues'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 40, color: AppColors.border),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('TOTAL PAID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success)),
                                    const SizedBox(height: 4),
                                    Text('₹${summary['totalPaid'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.success)),
                                  ],
                                ),
                              ),
                            ),
                            Container(width: 1, height: 40, color: AppColors.border),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('OUTSTANDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.error)),
                                    const SizedBox(height: 4),
                                    Text('₹${summary['outstanding'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.error)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const Text(
                      'Fee Invoices & Payment History',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),

                    if (student.fees.isEmpty)
                      EmptyStateView(
                        icon: Icons.receipt_long_outlined,
                        title: 'No fee records found',
                        description: 'Your academic fee receipts and institutional invoices will be displayed here.',
                      )
                    else
                      ...student.fees.map((f) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      f.feeTitle,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                    if (f.isPaid)
                                      StatusBadge.paid()
                                    else if (f.isPartial)
                                      const StatusBadge(label: 'Partial', backgroundColor: AppColors.infoLight, textColor: AppColors.info)
                                    else
                                      StatusBadge.pending(),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Due Date: ${f.dueDate} • Session: ${f.sessionName ?? "2026-2027"}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Amount: ₹${f.amount.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      'Paid: ₹${f.paidAmount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: f.isPaid ? AppColors.success : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (f.receiptReference != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Receipt Ref: ${f.receiptReference} (Paid: ${f.paymentDate ?? "Verified"})',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }
}
