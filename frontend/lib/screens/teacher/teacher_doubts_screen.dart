import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/app_card.dart';
import '../../models/doubt_model.dart';

class TeacherDoubtsScreen extends StatefulWidget {
  const TeacherDoubtsScreen({super.key});

  @override
  State<TeacherDoubtsScreen> createState() => _TeacherDoubtsScreenState();
}

class _TeacherDoubtsScreenState extends State<TeacherDoubtsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TeacherProvider>(context, listen: false).fetchAssignedDoubts();
    });
  }

  void _showReplyDialog(DoubtModel doubt) {
    final replyController = TextEditingController();

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
                    'Faculty Response: ${doubt.title}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Student: ${doubt.studentName} • ${doubt.subjectName}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                doubt.note,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: replyController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Academic Solution & Explanation',
                hintText: 'Explain the principle, reference the textbook page, or clarify the concept...',
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () async {
                final message = replyController.text.trim();
                if (message.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please write an explanation before submitting.')),
                  );
                  return;
                }

                final teacher = Provider.of<TeacherProvider>(context, listen: false);
                final ok = await teacher.respondToDoubt(doubt.id, message);

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Response sent to student!' : 'Failed to send response.'),
                      backgroundColor: ok ? AppColors.success : AppColors.error,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Send Response to Student'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacher = Provider.of<TeacherProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Doubts Queue'),
      ),
      body: teacher.isLoading
          ? const Center(child: CircularProgressIndicator())
          : teacher.assignedDoubts.isEmpty
              ? EmptyStateView(
                  icon: Icons.question_answer_outlined,
                  title: 'No pending student doubts',
                  description: 'All doubts in your assigned subjects and batches have been reviewed and answered.',
                )
              : RefreshIndicator(
                  onRefresh: () => teacher.fetchAssignedDoubts(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: teacher.assignedDoubts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final d = teacher.assignedDoubts[i];
                      return AppCard(
                        onTap: () => _showReplyDialog(d),
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
                                    '${d.subjectName} • Batch ${d.batchName ?? "PCM"}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                                if (d.isResolved)
                                  StatusBadge.resolved()
                                else if (d.isAnswered)
                                  const StatusBadge(label: 'Answered', backgroundColor: AppColors.successLight, textColor: AppColors.success)
                                else
                                  StatusBadge.open(),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              d.title,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            if (d.topic != null && d.topic!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Topic: ${d.topic}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              d.note,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Student: ${d.studentName ?? "Student"}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                ElevatedButton.icon(
                                  onPressed: () => _showReplyDialog(d),
                                  icon: const Icon(Icons.reply, size: 14),
                                  label: const Text('Reply', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(minimumSize: const Size(80, 32), padding: const EdgeInsets.symmetric(horizontal: 10)),
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
