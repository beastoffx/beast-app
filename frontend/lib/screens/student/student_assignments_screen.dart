import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../models/assignment_model.dart';
import '../../providers/student_provider.dart';
import '../../widgets/beast_components.dart';

class StudentAssignmentsScreen extends StatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  State<StudentAssignmentsScreen> createState() => _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState extends State<StudentAssignmentsScreen> {
  String _selectedFilter = 'all'; // 'all', 'pending', 'submitted', 'reviewed'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentProvider>(context, listen: false).fetchAssignments();
    });
  }

  void _showSubmissionDialog(AssignmentModel assignment) {
    final notesController = TextEditingController();
    final fileUrlController = TextEditingController(text: assignment.submissionFileUrl ?? '');
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
                    child: Text(
                      'Submit: ${assignment.title}',
                      style: BeastTypography.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Due: ${assignment.deadline} • Max Marks: ${assignment.maxMarks}',
                style: BeastTypography.caption,
              ),
              const SizedBox(height: BeastSpacing.lg),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Solution Summary / Explanatory Notes',
                  hintText: 'Enter your working, steps taken, or key observations...',
                ),
              ),
              const SizedBox(height: BeastSpacing.md),
              TextField(
                controller: fileUrlController,
                decoration: const InputDecoration(
                  labelText: 'Solution Attachment URL / File Link',
                  hintText: 'https://... or /uploads/...',
                  prefixIcon: Icon(Icons.attachment_rounded),
                ),
              ),
              const SizedBox(height: BeastSpacing.xl),
              BeastPrimaryButton(
                label: 'Submit Coursework',
                icon: Icons.send_rounded,
                isLoading: isSubmitting,
                onPressed: () async {
                  final notes = notesController.text.trim();
                  final fileUrl = fileUrlController.text.trim();
                  if (notes.isEmpty && fileUrl.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please provide solution notes or an attachment URL.')),
                    );
                    return;
                  }

                  setSheetState(() => isSubmitting = true);
                  final provider = Provider.of<StudentProvider>(context, listen: false);
                  final ok = await provider.submitAssignment(
                    assignment.id,
                    notes,
                    fileUrl: fileUrl.isNotEmpty ? fileUrl : null,
                  );

                  if (mounted) {
                    Navigator.pop(ctx);
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Assignment submitted successfully.'),
                          backgroundColor: BeastColors.success,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(provider.errorMessage ?? 'Submission failed.'),
                          backgroundColor: BeastColors.danger,
                        ),
                      );
                    }
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
    final student = Provider.of<StudentProvider>(context);

    List<AssignmentModel> list = student.assignments;
    if (_selectedFilter == 'pending') {
      list = list.where((a) => !a.isSubmitted).toList();
    } else if (_selectedFilter == 'submitted') {
      list = list.where((a) => a.isSubmitted && !a.isReviewed).toList();
    } else if (_selectedFilter == 'reviewed') {
      list = list.where((a) => a.isReviewed).toList();
    }

    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Coursework & Assignments'),
      ),
      body: student.isLoading && student.assignments.isEmpty
          ? const BeastLoadingState(message: 'Loading assignments...')
          : student.errorMessage != null && student.assignments.isEmpty
              ? BeastErrorState(
                  message: student.errorMessage!,
                  onRetry: () => student.fetchAssignments(),
                )
              : Column(
                  children: [
                    _buildFilterChips(),
                    Expanded(
                      child: list.isEmpty
                          ? BeastEmptyState(
                              icon: Icons.assignment_turned_in_outlined,
                              title: _selectedFilter == 'all'
                                  ? 'No Assignments'
                                  : 'No ${_selectedFilter.toUpperCase()} Assignments',
                              message: 'Assignments posted by faculty will appear here.',
                            )
                          : RefreshIndicator(
                              onRefresh: () => student.fetchAssignments(),
                              color: BeastColors.brandPrimary,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(BeastSpacing.lg),
                                itemCount: list.length,
                                separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                                itemBuilder: (ctx, i) => _buildAssignmentCard(list[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: BeastColors.white,
      padding: const EdgeInsets.symmetric(horizontal: BeastSpacing.lg, vertical: BeastSpacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chip('all', 'All Work'),
            const SizedBox(width: 8),
            _chip('pending', 'Pending Submission'),
            const SizedBox(width: 8),
            _chip('submitted', 'Awaiting Review'),
            const SizedBox(width: 8),
            _chip('reviewed', 'Graded'),
          ],
        ),
      ),
    );
  }

  Widget _chip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = key),
      selectedColor: BeastColors.peach200,
      backgroundColor: BeastColors.neutral100,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? BeastColors.dark900 : BeastColors.textSecondary,
      ),
      side: BorderSide(
        color: isSelected ? BeastColors.peach400 : BeastColors.borderSubtle,
      ),
    );
  }

  Widget _buildAssignmentCard(AssignmentModel assignment) {
    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: BeastColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(BeastRadius.xs),
                ),
                child: Text(
                  assignment.subjectName ?? 'General',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: BeastColors.dark900,
                  ),
                ),
              ),
              BeastStatusBadge(status: assignment.submissionStatus ?? 'pending'),
            ],
          ),
          const SizedBox(height: BeastSpacing.md),
          Text(assignment.title, style: BeastTypography.title),
          const SizedBox(height: 4),
          Text(
            assignment.description,
            style: BeastTypography.body.copyWith(color: BeastColors.textSecondary),
          ),
          const SizedBox(height: BeastSpacing.md),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: BeastColors.textMuted),
              const SizedBox(width: 4),
              Text('Due: ${assignment.deadline}', style: BeastTypography.caption),
              const SizedBox(width: 14),
              const Icon(Icons.grade_outlined, size: 14, color: BeastColors.textMuted),
              const SizedBox(width: 4),
              Text('Max: ${assignment.maxMarks} marks', style: BeastTypography.caption),
            ],
          ),
          if (assignment.isSubmitted && assignment.marksObtained != null) ...[
            const SizedBox(height: BeastSpacing.md),
            Container(
              padding: const EdgeInsets.all(BeastSpacing.md),
              decoration: BoxDecoration(
                color: BeastColors.successLight,
                borderRadius: BorderRadius.circular(BeastRadius.sm),
                border: Border.all(color: BeastColors.success.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: BeastColors.success, size: 20),
                  const SizedBox(width: BeastSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Score: ${assignment.marksObtained} / ${assignment.maxMarks}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: BeastColors.success),
                        ),
                        if (assignment.feedback != null && assignment.feedback!.isNotEmpty)
                          Text('Feedback: ${assignment.feedback}', style: BeastTypography.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!assignment.isSubmitted) ...[
            const SizedBox(height: BeastSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: BeastPrimaryButton(
                label: 'Submit Solution',
                icon: Icons.upload_file_rounded,
                height: 40,
                onPressed: () => _showSubmissionDialog(assignment),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
