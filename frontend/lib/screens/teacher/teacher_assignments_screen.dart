import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/beast_tokens.dart';
import '../../models/assignment_model.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/beast_components.dart';

class TeacherAssignmentsScreen extends StatefulWidget {
  const TeacherAssignmentsScreen({super.key});

  @override
  State<TeacherAssignmentsScreen> createState() => _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState extends State<TeacherAssignmentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TeacherProvider>(context, listen: false).fetchAssignments();
    });
  }

  void _showCreateAssignmentDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final maxMarksController = TextEditingController(text: '50');
    DateTime selectedDeadline = DateTime.now().add(const Duration(days: 3));
    String selectedSubjectId = 'sub-phy-12';
    String selectedBatchId = 'batch-pcm-2027-a';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BeastColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BeastRadius.lg)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                  Text('Create Coursework Assignment', style: BeastTypography.title),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: BeastSpacing.md),
              DropdownButtonFormField<String>(
                value: selectedBatchId,
                decoration: const InputDecoration(labelText: 'Target Batch'),
                items: const [
                  DropdownMenuItem(value: 'batch-pcm-2027-a', child: Text('Class 12 - PCM Batch A')),
                  DropdownMenuItem(value: 'batch-pcb-2027-a', child: Text('Class 12 - PCB Batch A')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedBatchId = val);
                },
              ),
              const SizedBox(height: BeastSpacing.md),
              DropdownButtonFormField<String>(
                value: selectedSubjectId,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: const [
                  DropdownMenuItem(value: 'sub-phy-12', child: Text('Physics (PHY-12)')),
                  DropdownMenuItem(value: 'sub-chm-12', child: Text('Chemistry (CHM-12)')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedSubjectId = val);
                },
              ),
              const SizedBox(height: BeastSpacing.md),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Assignment Title', hintText: 'e.g. Electromagnetic Waves Problem Set'),
              ),
              const SizedBox(height: BeastSpacing.md),
              TextField(
                controller: descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Instructions & Problem Description'),
              ),
              const SizedBox(height: BeastSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: maxMarksController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max Marks'),
                    ),
                  ),
                  const SizedBox(width: BeastSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month_outlined, size: 16),
                      label: Text(DateFormat('dd MMM').format(selectedDeadline)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeastRadius.sm)),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDeadline,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) setModalState(() => selectedDeadline = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BeastSpacing.xl),
              BeastPrimaryButton(
                label: 'Publish Assignment',
                icon: Icons.publish_rounded,
                isLoading: isSubmitting,
                onPressed: () async {
                  final title = titleController.text.trim();
                  final desc = descriptionController.text.trim();
                  final maxMarks = int.tryParse(maxMarksController.text.trim()) ?? 50;

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter an assignment title.')),
                    );
                    return;
                  }

                  setModalState(() => isSubmitting = true);
                  final teacher = Provider.of<TeacherProvider>(context, listen: false);
                  final ok = await teacher.createAssignment(
                    title: title,
                    description: desc,
                    batchId: selectedBatchId,
                    subjectId: selectedSubjectId,
                    deadline: DateFormat('yyyy-MM-dd').format(selectedDeadline),
                    maxMarks: maxMarks,
                  );

                  if (mounted) {
                    Navigator.pop(ctx);
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Assignment published successfully.'),
                          backgroundColor: BeastColors.success,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(teacher.errorMessage ?? 'Failed to publish.'),
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

  void _showSubmissionsSheet(AssignmentModel assignment) {
    final teacher = Provider.of<TeacherProvider>(context, listen: false);
    teacher.fetchSubmissions(assignment.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BeastColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(BeastRadius.lg)),
      ),
      builder: (ctx) => Consumer<TeacherProvider>(
        builder: (context, prov, _) {
          final subs = prov.submissions;
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(BeastSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Submissions: ${assignment.title}',
                        style: BeastTypography.h3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Text('Total: ${subs.length} student submissions', style: BeastTypography.caption),
                const SizedBox(height: BeastSpacing.md),
                const Divider(color: BeastColors.borderSubtle),
                Expanded(
                  child: subs.isEmpty
                      ? const BeastEmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'No Submissions Yet',
                          subtitle: 'Enrolled students have not submitted solutions for this coursework yet.',
                        )
                      : ListView.separated(
                          itemCount: subs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.sm),
                          itemBuilder: (context, idx) {
                            final s = subs[idx];
                            final subId = s.id;
                            final stuName = s.studentName ?? 'Student';
                            final score = s.marks;
                            final isGraded = score != null;

                            return BeastCard(
                              padding: const EdgeInsets.all(BeastSpacing.md),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(stuName, style: BeastTypography.bodyMedium),
                                        if (s.submittedAt.isNotEmpty)
                                          Text('Submitted: ${s.submittedAt.length >= 10 ? s.submittedAt.substring(0, 10) : s.submittedAt}', style: BeastTypography.caption),
                                      ],
                                    ),
                                  ),
                                  if (isGraded)
                                    BeastBadge(
                                      label: '$score / ${assignment.maxMarks}',
                                      backgroundColor: BeastColors.successLight,
                                      textColor: BeastColors.success,
                                    )
                                  else
                                    ElevatedButton(
                                      onPressed: () => _showGradingDialog(subId, stuName, assignment.maxMarks),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: BeastColors.brandPrimary,
                                        foregroundColor: BeastColors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      ),
                                      child: const Text('Grade'),
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
        },
      ),
    );
  }

  void _showGradingDialog(String submissionId, String studentName, int maxMarks) {
    final marksCtrl = TextEditingController();
    final feedbackCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeastRadius.md)),
        backgroundColor: BeastColors.white,
        title: Text('Grade Submission: $studentName', style: BeastTypography.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: marksCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Marks Awarded (Max: $maxMarks)',
              ),
            ),
            const SizedBox(height: BeastSpacing.md),
            TextField(
              controller: feedbackCtrl,
              decoration: const InputDecoration(
                labelText: 'Teacher Feedback / Remarks',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final marks = double.tryParse(marksCtrl.text.trim());
              if (marks == null || marks < 0 || marks > maxMarks) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter valid marks between 0 and $maxMarks.')),
                );
                return;
              }

              final teacher = Provider.of<TeacherProvider>(context, listen: false);
              final ok = await teacher.gradeSubmission(
                submissionId,
                marks.toInt(),
                feedbackCtrl.text.trim(),
              );

              if (mounted) {
                Navigator.pop(ctx);
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Grade recorded successfully.'), backgroundColor: BeastColors.success),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BeastColors.brandPrimary,
              foregroundColor: BeastColors.white,
            ),
            child: const Text('Save Grade'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacher = Provider.of<TeacherProvider>(context);

    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Faculty Coursework Studio'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAssignmentDialog,
        backgroundColor: BeastColors.brandPrimary,
        foregroundColor: BeastColors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Create Assignment'),
      ),
      body: teacher.isLoading && teacher.assignments.isEmpty
          ? const BeastLoadingState(message: 'Loading coursework...')
          : teacher.errorMessage != null && teacher.assignments.isEmpty
              ? BeastErrorState(
                  message: teacher.errorMessage!,
                  onRetry: () => teacher.fetchAssignments(),
                )
              : teacher.assignments.isEmpty
                  ? const BeastEmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No Assignments Created',
                      message: 'Tap "Create Assignment" to publish homework and problem sets to your batches.',
                    )
                  : RefreshIndicator(
                      onRefresh: () => teacher.fetchAssignments(),
                      color: BeastColors.brandPrimary,
                      child: ListView.separated(
                        padding: const EdgeInsets.only(
                          left: BeastSpacing.lg,
                          right: BeastSpacing.lg,
                          top: BeastSpacing.lg,
                          bottom: 80,
                        ),
                        itemCount: teacher.assignments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                        itemBuilder: (ctx, i) {
                          final a = teacher.assignments[i];
                          return BeastCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    BeastBadge(
                                      label: a.subjectName ?? 'Subject',
                                      variant: BeastBadgeVariant.peach,
                                    ),
                                    Text('Max: ${a.maxMarks} marks', style: BeastTypography.caption),
                                  ],
                                ),
                                const SizedBox(height: BeastSpacing.sm),
                                Text(a.title, style: BeastTypography.title),
                                const SizedBox(height: 4),
                                Text(a.description, style: BeastTypography.body.copyWith(color: BeastColors.textSecondary)),
                                const SizedBox(height: BeastSpacing.md),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Due: ${a.deadline}', style: BeastTypography.caption),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.people_outline_rounded, size: 16),
                                      label: const Text('View Submissions'),
                                      onPressed: () => _showSubmissionsSheet(a),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
