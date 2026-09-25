import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/app_card.dart';
import '../../models/assignment_model.dart';

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
    final instructionsController = TextEditingController();
    final maxMarksController = TextEditingController(text: '50');
    DateTime selectedDeadline = DateTime.now().add(const Duration(days: 3));
    String selectedSubjectId = 'sub-phy-12';
    String selectedBatchId = 'batch-pcm-2027-a';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Create New Assignment', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedBatchId,
                decoration: const InputDecoration(labelText: 'Target Batch'),
                items: const [
                  DropdownMenuItem(value: 'batch-pcm-2027-a', child: Text('PCM-2027-A (Class 12)')),
                  DropdownMenuItem(value: 'batch-pcb-2027-b', child: Text('PCB-2027-B (Class 12)')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedBatchId = val);
                },
              ),
              const SizedBox(height: 10),
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
              const SizedBox(height: 10),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Assignment Title', hintText: 'e.g. Wave Optics Homework 3'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description / Problems to solve'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: instructionsController,
                decoration: const InputDecoration(labelText: 'Special Instructions / Submission Format (Optional)'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: maxMarksController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max Marks'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDeadline,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDeadline = picked);
                        }
                      },
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(DateFormat('dd MMM').format(selectedDeadline)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please specify assignment title.')),
                    );
                    return;
                  }

                  final deadlineStr = '${DateFormat("yyyy-MM-dd").format(selectedDeadline)} 23:59';
                  final teacher = Provider.of<TeacherProvider>(context, listen: false);
                  final ok = await teacher.createAssignment(
                    title: title,
                    subjectId: selectedSubjectId,
                    batchId: selectedBatchId,
                    deadline: deadlineStr,
                    description: descriptionController.text.trim(),
                    instructions: instructionsController.text.trim(),
                    maxMarks: int.tryParse(maxMarksController.text.trim()) ?? 50,
                  );

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Assignment published to batch!' : 'Failed to create assignment.'),
                        backgroundColor: ok ? AppColors.success : AppColors.error,
                      ),
                    );
                  }
                },
                child: const Text('Publish Assignment to Students'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubmissionsModal(AssignmentModel assignment) {
    final teacher = Provider.of<TeacherProvider>(context, listen: false);
    teacher.fetchSubmissions(assignment.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer<TeacherProvider>(
        builder: (context, prov, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Submissions: ${assignment.title}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${prov.submissions.length} submissions received • Max marks: ${assignment.maxMarks}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                Expanded(
                  child: prov.submissions.isEmpty
                      ? const Center(child: Text('No student submissions received yet.'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount: prov.submissions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final sub = prov.submissions[i];
                            return AppCard(
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppColors.primaryLight.withOpacity(0.1),
                                    child: Text(
                                      (sub.studentName ?? 'S')[0],
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(sub.studentName ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                        Text('Submitted: ${sub.submittedAt}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                        if (sub.notes != null && sub.notes!.isNotEmpty)
                                          Text('"${sub.notes}"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                      ],
                                    ),
                                  ),
                                  if (sub.marks != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(8)),
                                      child: Text(
                                        '${sub.marks} / ${assignment.maxMarks}',
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success),
                                      ),
                                    )
                                  else
                                    ElevatedButton(
                                      onPressed: () => _showGradingDialog(sub, assignment.maxMarks),
                                      style: ElevatedButton.styleFrom(minimumSize: const Size(70, 32), padding: const EdgeInsets.symmetric(horizontal: 10)),
                                      child: const Text('Grade', style: TextStyle(fontSize: 12)),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGradingDialog(AssignmentSubmissionModel sub, int maxMarks) {
    final marksController = TextEditingController(text: sub.marks?.toString() ?? '');
    final feedbackController = TextEditingController(text: sub.feedback ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Grade: ${sub.studentName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: marksController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Marks Awarded (Max $maxMarks)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Teacher Feedback',
                hintText: 'e.g. Well done on step 4, review torque balance.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final marks = int.tryParse(marksController.text.trim()) ?? 0;
              final teacher = Provider.of<TeacherProvider>(context, listen: false);
              final ok = await teacher.gradeSubmission(sub.id, marks, feedbackController.text.trim());
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Grade and feedback recorded.' : 'Failed to grade submission.')),
                );
              }
            },
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
      appBar: AppBar(
        title: const Text('Assignments Management'),
      ),
      body: teacher.isLoading
          ? const Center(child: CircularProgressIndicator())
          : teacher.assignments.isEmpty
              ? EmptyStateView(
                  icon: Icons.assignment_outlined,
                  title: 'No assignments created yet',
                  description: 'Create your first assignment and distribute homework problem sets to your batches.',
                  actionLabel: 'Create Assignment',
                  onAction: _showCreateAssignmentDialog,
                )
              : RefreshIndicator(
                  onRefresh: () => teacher.fetchAssignments(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: teacher.assignments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final a = teacher.assignments[i];
                      return AppCard(
                        onTap: () => _showSubmissionsModal(a),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${a.subjectName} • ${a.batchName}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              a.title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              a.description,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Deadline: ${a.deadline}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                Text('Max: ${a.maxMarks} marks', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateAssignmentDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Assignment', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
