import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/student_provider.dart';
import '../../widgets/app_card.dart';
import '../../models/assignment_model.dart';

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
    final notesController = TextEditingController(text: assignment.feedback != null ? '' : '');
    final fileUrlController = TextEditingController(text: assignment.submissionFileUrl ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
                Expanded(
                  child: Text(
                    'Submit: ${assignment.title}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Deadline: ${assignment.deadline} • Max Marks: ${assignment.maxMarks}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Submission Notes / Solution Summary',
                hintText: 'Describe your method, steps taken, or questions...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fileUrlController,
              decoration: const InputDecoration(
                labelText: 'Solution File Attachment Link / Cloud Path',
                hintText: '/uploads/submissions/my_solution.pdf',
                prefixIcon: Icon(Icons.attachment),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final notes = notesController.text.trim();
                final fileUrl = fileUrlController.text.trim();
                if (notes.isEmpty && fileUrl.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please provide submission notes or an attachment URL.')),
                  );
                  return;
                }

                final provider = Provider.of<StudentProvider>(context, listen: false);
                final ok = await provider.submitAssignment(
                  assignment.id,
                  notes,
                  fileUrl: fileUrl.isNotEmpty ? fileUrl : null,
                );

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Assignment submitted successfully!' : 'Failed to submit assignment.'),
                      backgroundColor: ok ? AppColors.success : AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Confirm & Submit Assignment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = Provider.of<StudentProvider>(context);

    List<AssignmentModel> filtered = student.assignments;
    if (_selectedFilter == 'pending') {
      filtered = filtered.where((a) => !a.isSubmitted).toList();
    } else if (_selectedFilter == 'submitted') {
      filtered = filtered.where((a) => a.isSubmitted && !a.isReviewed).toList();
    } else if (_selectedFilter == 'reviewed') {
      filtered = filtered.where((a) => a.isReviewed).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assignments'),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${student.assignments.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('pending', 'Pending (${student.assignments.where((a) => !a.isSubmitted).length})'),
                const SizedBox(width: 8),
                _buildFilterChip('submitted', 'Submitted (${student.assignments.where((a) => a.isSubmitted && !a.isReviewed).length})'),
                const SizedBox(width: 8),
                _buildFilterChip('reviewed', 'Graded (${student.assignments.where((a) => a.isReviewed).length})'),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: student.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? EmptyStateView(
                        icon: Icons.assignment_turned_in_outlined,
                        title: 'No Assignments in this section',
                        description: 'When teachers post assignments for your batch, they will appear here.',
                      )
                    : RefreshIndicator(
                        onRefresh: () => student.fetchAssignments(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final assign = filtered[i];
                            return AppCard(
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
                                          assign.subjectName ?? 'Subject',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ),
                                      if (assign.isReviewed)
                                        StatusBadge.reviewed()
                                      else if (assign.isSubmitted)
                                        StatusBadge.submitted()
                                      else
                                        StatusBadge.pending(),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    assign.title,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    assign.description,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Due: ${assign.deadline} • Max Marks: ${assign.maxMarks}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),

                                  // Reviewed feedback & marks
                                  if (assign.isReviewed) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.successLight,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Teacher Review',
                                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.success),
                                              ),
                                              Text(
                                                'Marks: ${assign.marksObtained} / ${assign.maxMarks}',
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.success),
                                              ),
                                            ],
                                          ),
                                          if (assign.feedback != null && assign.feedback!.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              '"${assign.feedback}"',
                                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textPrimary),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Action Button
                                  if (!assign.isReviewed) ...[
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _showSubmissionDialog(assign),
                                        icon: Icon(assign.isSubmitted ? Icons.edit : Icons.upload, size: 16),
                                        label: Text(assign.isSubmitted ? 'Resubmit Solution' : 'Submit Solution'),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(140, 36),
                                        ),
                                      ),
                                    ),
                                  ],
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

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = key),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}
