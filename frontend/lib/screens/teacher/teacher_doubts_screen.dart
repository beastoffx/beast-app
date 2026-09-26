import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../models/doubt_model.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/beast_components.dart';

class TeacherDoubtsScreen extends StatefulWidget {
  const TeacherDoubtsScreen({super.key});

  @override
  State<TeacherDoubtsScreen> createState() => _TeacherDoubtsScreenState();
}

class _TeacherDoubtsScreenState extends State<TeacherDoubtsScreen> {
  String _filter = 'pending'; // 'pending' | 'resolved' | 'all'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TeacherProvider>(context, listen: false).fetchAssignedDoubts();
    });
  }

  void _showReplyDialog(DoubtModel doubt) {
    final replyController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BeastColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BeastRadius.lg)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: BeastSpacing.xl,
            right: BeastSpacing.xl,
            top: BeastSpacing.xxl,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + BeastSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Respond to Question', style: BeastTypography.title),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Student: ${doubt.studentName} • ${doubt.subjectName ?? "Subject"}',
                style: BeastTypography.caption,
              ),
              const SizedBox(height: BeastSpacing.md),
              Container(
                padding: const EdgeInsets.all(BeastSpacing.md),
                decoration: BoxDecoration(
                  color: BeastColors.neutral100,
                  borderRadius: BorderRadius.circular(BeastRadius.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doubt.title, style: BeastTypography.bodyMedium),
                    const SizedBox(height: 4),
                    Text(doubt.note, style: BeastTypography.caption),
                  ],
                ),
              ),
              const SizedBox(height: BeastSpacing.lg),
              TextField(
                controller: replyController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Faculty Explanation & Working',
                  hintText: 'Clarify the concept, reference formula derivations, or explain steps...',
                ),
              ),
              const SizedBox(height: BeastSpacing.xl),
              BeastPrimaryButton(
                label: 'Send Clarification',
                icon: Icons.send_rounded,
                isLoading: isSubmitting,
                onPressed: () async {
                  final message = replyController.text.trim();
                  if (message.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please write an explanation.')),
                    );
                    return;
                  }

                  setSheetState(() => isSubmitting = true);
                  final teacher = Provider.of<TeacherProvider>(context, listen: false);
                  final ok = await teacher.respondToDoubt(doubt.id, message);

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Response sent to student successfully.' : 'Failed to send response.'),
                        backgroundColor: ok ? BeastColors.success : BeastColors.danger,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacher = Provider.of<TeacherProvider>(context);

    final list = teacher.assignedDoubts.where((d) {
      if (_filter == 'pending') return d.status.toUpperCase() != 'RESOLVED';
      if (_filter == 'resolved') return d.status.toUpperCase() == 'RESOLVED';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Faculty Doubt Inbox'),
      ),
      body: teacher.isLoading && teacher.assignedDoubts.isEmpty
          ? const BeastLoadingState(message: 'Loading assigned student doubts...')
          : teacher.errorMessage != null && teacher.assignedDoubts.isEmpty
              ? BeastErrorState(
                  message: teacher.errorMessage!,
                  onRetry: () => teacher.fetchAssignedDoubts(),
                )
              : Column(
                  children: [
                    Container(
                      color: BeastColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: BeastSpacing.lg, vertical: BeastSpacing.sm),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Unanswered'),
                            selected: _filter == 'pending',
                            selectedColor: BeastColors.peach200,
                            backgroundColor: BeastColors.neutral100,
                            onSelected: (_) => setState(() => _filter = 'pending'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Resolved'),
                            selected: _filter == 'resolved',
                            selectedColor: BeastColors.peach200,
                            backgroundColor: BeastColors.neutral100,
                            onSelected: (_) => setState(() => _filter = 'resolved'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('All Questions'),
                            selected: _filter == 'all',
                            selectedColor: BeastColors.peach200,
                            backgroundColor: BeastColors.neutral100,
                            onSelected: (_) => setState(() => _filter = 'all'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: BeastColors.borderSubtle, height: 1),
                    Expanded(
                      child: list.isEmpty
                          ? BeastEmptyState(
                              icon: Icons.question_answer_outlined,
                              title: _filter == 'pending' ? 'No Pending Doubts' : 'No Questions Found',
                              message: _filter == 'pending'
                                  ? 'All assigned student questions have been addressed.'
                                  : 'Student queries matching the selected filter will appear here.',
                            )
                          : RefreshIndicator(
                              onRefresh: () => teacher.fetchAssignedDoubts(),
                              color: BeastColors.brandPrimary,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(BeastSpacing.lg),
                                itemCount: list.length,
                                separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                                itemBuilder: (ctx, i) {
                                  final d = list[i];
                                  final isResolved = d.status.toUpperCase() == 'RESOLVED';

                                  return BeastCard(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${d.studentName} • ${d.subjectName ?? "General"}',
                                              style: BeastTypography.caption.copyWith(fontWeight: FontWeight.w700),
                                            ),
                                            BeastStatusBadge(status: d.status),
                                          ],
                                        ),
                                        const SizedBox(height: BeastSpacing.sm),
                                        Text(d.title, style: BeastTypography.title),
                                        const SizedBox(height: 4),
                                        Text(d.note, style: BeastTypography.body.copyWith(color: BeastColors.textSecondary)),
                                        const SizedBox(height: BeastSpacing.md),
                                        if (!isResolved)
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.reply_rounded, size: 16),
                                              label: const Text('Compose Answer'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: BeastColors.brandPrimary,
                                                foregroundColor: BeastColors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              ),
                                              onPressed: () => _showReplyDialog(d),
                                            ),
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
