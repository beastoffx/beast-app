import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/student_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_card.dart';
import '../../models/doubt_model.dart';

class StudentDoubtsScreen extends StatefulWidget {
  const StudentDoubtsScreen({super.key});

  @override
  State<StudentDoubtsScreen> createState() => _StudentDoubtsScreenState();
}

class _StudentDoubtsScreenState extends State<StudentDoubtsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentProvider>(context, listen: false).fetchDoubts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateDoubtDialog() {
    final titleController = TextEditingController();
    final topicController = TextEditingController();
    final noteController = TextEditingController();
    final imageUrlController = TextEditingController();
    String selectedSubjectId = 'sub-phy-12';
    String priority = 'normal';

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
                  const Row(
                    children: [
                      Icon(Icons.help_outline, color: AppColors.secondary, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Capture Academic Doubt',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Subject Dropdown
              DropdownButtonFormField<String>(
                value: selectedSubjectId,
                decoration: const InputDecoration(labelText: 'Enrolled Subject'),
                items: const [
                  DropdownMenuItem(value: 'sub-phy-12', child: Text('Physics (PHY-12)')),
                  DropdownMenuItem(value: 'sub-chm-12', child: Text('Chemistry (CHM-12)')),
                  DropdownMenuItem(value: 'sub-mth-12', child: Text('Mathematics (MTH-12)')),
                  DropdownMenuItem(value: 'sub-bio-12', child: Text('Biology (BIO-12)')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedSubjectId = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Doubt Headline / Question Title',
                  hintText: 'e.g. Work done by static friction during rolling',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: topicController,
                decoration: const InputDecoration(
                  labelText: 'Chapter / Specific Topic (Optional)',
                  hintText: 'e.g. Rotational Dynamics Chapter 7',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Detailed Academic Question',
                  hintText: 'Specify exactly what step or theorem is confusing you...',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Question Photo / Diagram Link (Optional)',
                  hintText: '/uploads/doubts/question_diagram.png',
                  prefixIcon: Icon(Icons.camera_alt_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Priority:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Normal'),
                    selected: priority == 'normal',
                    onSelected: (_) => setModalState(() => priority = 'normal'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Urgent'),
                    selected: priority == 'high',
                    selectedColor: AppColors.errorLight,
                    onSelected: (_) => setModalState(() => priority = 'high'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final note = noteController.text.trim();
                  if (title.isEmpty || note.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please provide a title and detailed question.')),
                    );
                    return;
                  }

                  final provider = Provider.of<StudentProvider>(context, listen: false);
                  final ok = await provider.createDoubt(
                    subjectId: selectedSubjectId,
                    title: title,
                    topic: topicController.text.trim(),
                    note: note,
                    imageUrl: imageUrlController.text.trim().isNotEmpty ? imageUrlController.text.trim() : null,
                    priority: priority,
                  );

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Doubt shared with your faculty!' : 'Failed to submit doubt.'),
                        backgroundColor: ok ? AppColors.success : AppColors.error,
                      ),
                    );
                  }
                },
                child: const Text('Save & Transmit to Faculty'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDoubtDetailSheet(DoubtModel doubt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DoubtDiscussionSheet(doubtId: doubt.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = Provider.of<StudentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DoubtDeck — Academic Q&A'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Open Doubts (${student.openDoubts.length})'),
            Tab(text: 'Resolved (${student.resolvedDoubts.length})'),
          ],
        ),
      ),
      body: student.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDoubtList(student.openDoubts, isResolvedTab: false),
                _buildDoubtList(student.resolvedDoubts, isResolvedTab: true),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDoubtDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.secondary,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Ask a Doubt', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildDoubtList(List<DoubtModel> doubts, {required bool isResolvedTab}) {
    if (doubts.isEmpty) {
      return EmptyStateView(
        icon: Icons.question_answer_outlined,
        title: isResolvedTab ? 'No resolved doubts yet' : 'No open doubts currently',
        description: isResolvedTab
            ? 'When your questions are answered and you mark them resolved, they are filed here for future revision.'
            : 'Got stuck on a formula, derivation, or problem? Tap below to ask your faculty.',
        actionLabel: isResolvedTab ? null : 'Ask a Doubt',
        onAction: isResolvedTab ? null : _showCreateDoubtDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: () => Provider.of<StudentProvider>(context, listen: false).fetchDoubts(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: doubts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final d = doubts[i];
          return AppCard(
            onTap: () => _showDoubtDetailSheet(d),
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
                        d.subjectName ?? 'Subject',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    if (d.isResolved)
                      StatusBadge.resolved()
                    else if (d.isAnswered)
                      const StatusBadge(
                        label: 'Faculty Replied',
                        backgroundColor: AppColors.successLight,
                        textColor: AppColors.success,
                        icon: Icons.check,
                      )
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
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${d.responseCount} faculty replies',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const Row(
                      children: [
                        Text('Open Thread', style: TextStyle(fontSize: 12, color: AppColors.primaryLight, fontWeight: FontWeight.w700)),
                        Icon(Icons.chevron_right, size: 16, color: AppColors.primaryLight),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class DoubtDiscussionSheet extends StatefulWidget {
  final String doubtId;
  const DoubtDiscussionSheet({super.key, required this.doubtId});

  @override
  State<DoubtDiscussionSheet> createState() => _DoubtDiscussionSheetState();
}

class _DoubtDiscussionSheetState extends State<DoubtDiscussionSheet> {
  bool _loading = true;
  Map<String, dynamic>? _doubtData;
  List<dynamic> _responses = [];
  final _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    final student = Provider.of<StudentProvider>(context, listen: false);
    final res = await student.createDoubt(
      subjectId: 'noop', title: '', note: ''
    ); // Just to verify; let's call API directly
    // Using ApiService
    final api = student.isLoading; // placeholder
    // We can fetch via student provider
    final response = await Provider.of<StudentProvider>(context, listen: false)
        .fetchDoubts();
    // Fetch doubt thread
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final student = Provider.of<StudentProvider>(context);
    final doubt = student.allDoubts.firstWhere(
      (d) => d.id == widget.doubtId,
      orElse: () => DoubtModel(id: widget.doubtId, studentId: '', subjectId: '', title: 'Doubt Discussion', note: '', status: 'open', priority: 'normal'),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                  doubt.title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Subject: ${doubt.subjectName ?? "Subject"} • Status: ${doubt.status.toUpperCase()}',
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
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await student.resolveDoubt(doubt.id, false);
                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('Still Unclear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await student.resolveDoubt(doubt.id, true);
                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Mark Resolved'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
