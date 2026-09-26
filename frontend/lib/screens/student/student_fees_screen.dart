import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../models/fee_exam_model.dart';
import '../../providers/student_provider.dart';
import '../../widgets/beast_components.dart';

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
      backgroundColor: BeastColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Fee Ledger & Receipts'),
      ),
      body: student.isLoading && student.fees.isEmpty
          ? const BeastLoadingState(message: 'Loading financial ledger...')
          : student.errorMessage != null && student.fees.isEmpty
              ? BeastErrorState(
                  message: student.errorMessage!,
                  onRetry: () => student.fetchFees(),
                )
              : RefreshIndicator(
                  onRefresh: () => student.fetchFees(),
                  color: BeastColors.brandPrimary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(BeastSpacing.lg),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (summary != null) ...[
                              _buildSummaryCard(summary),
                              const SizedBox(height: BeastSpacing.xl),
                            ],
                            const BeastSectionHeader(title: 'Fee Installments & Receipts'),
                            const Divider(color: BeastColors.borderSubtle),
                            if (student.fees.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: BeastSpacing.xxl),
                                child: BeastEmptyState(
                                  icon: Icons.payments_outlined,
                                  title: 'No Fee Demands',
                                  message: 'All fee records, receipts, and payment schedules will appear here.',
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: student.fees.length,
                                separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                                itemBuilder: (ctx, i) => _buildFeeRecordCard(student.fees[i]),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> summary) {
    final totalBilled = summary['totalDues'] ?? 0;
    final totalPaid = summary['totalPaid'] ?? 0;
    final outstanding = summary['outstanding'] ?? 0;

    return BeastCard(
      padding: const EdgeInsets.all(BeastSpacing.xl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL BILLED', style: BeastTypography.label.copyWith(fontSize: 10)),
                const SizedBox(height: 4),
                Text('₹$totalBilled', style: BeastTypography.headline.copyWith(fontSize: 18)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: BeastColors.borderSubtle),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL PAID', style: BeastTypography.label.copyWith(fontSize: 10, color: BeastColors.success)),
                  const SizedBox(height: 4),
                  Text('₹$totalPaid', style: BeastTypography.headline.copyWith(fontSize: 18, color: BeastColors.success)),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 40, color: BeastColors.borderSubtle),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OUTSTANDING', style: BeastTypography.label.copyWith(fontSize: 10, color: BeastColors.danger)),
                  const SizedBox(height: 4),
                  Text('₹$outstanding', style: BeastTypography.headline.copyWith(fontSize: 18, color: BeastColors.danger)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRecordCard(FeeRecordModel f) {
    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(f.feeTitle, style: BeastTypography.title),
              BeastStatusBadge(status: f.status),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount Billed: ₹${f.amount.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (f.paidAmount > 0)
                Text(
                  'Paid: ₹${f.paidAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: BeastColors.success),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: BeastColors.textMuted),
              const SizedBox(width: 4),
              Text('Due Date: ${f.dueDate}', style: BeastTypography.caption),
              if (f.receiptReference != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.receipt_outlined, size: 13, color: BeastColors.textMuted),
                const SizedBox(width: 4),
                Text(f.receiptReference!, style: BeastTypography.caption),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
