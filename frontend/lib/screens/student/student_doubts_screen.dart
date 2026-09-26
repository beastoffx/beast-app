import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../models/doubt_model.dart';
import '../../providers/student_provider.dart';
import '../../widgets/beast_components.dart';

class StudentDoubtsScreen extends StatefulWidget {
  const StudentDoubtsScreen({super.key});

  @override
  State<StudentDoubtsScreen> createState() => _StudentDoubtsScreenState();
}

class _StudentDoubtsScreenState extends State<StudentDoubtsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DoubtModel? _selectedDoubt;

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
    final noteController = TextEditingController();
    final imageUrlController = TextEditingController();
    String selectedSubjectId = 'sub-phy-12';
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
                  Text('Submit Academic Doubt', style: BeastTypography.title),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: BeastSpacing.md),
              DropdownButtonFormField<String>(
                value: selectedSubjectId,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: const [
                  DropdownMenuItem(value: 'sub-phy-12', child: Text('Physics')),
                  DropdownMenuItem(value: 'sub-chm-12', child: Text('Chemistry')),
                  DropdownMenuItem(value: 'sub-mth-12', child: Text('Mathematics')),
                  DropdownMenuItem(value: 'sub-bio-12', child: Text('Biology')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedSubjectId = val);
                },
              ),
              const SizedBox(height: BeastSpacing.md),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Question Title / Topic',
                  hintText: 'e.g. Work-energy theorem in non-inertial frame',
                ),
              ),
              const SizedBox(height: BeastSpacing.md),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Detailed Explanation of Doubt',
                  hintText: 'Describe where you are stuck, steps attempted, or concept doubt...',
                ),
              ),
              const SizedBox(height: BeastSpacing.md),
              TextField(
                controller: imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Optional Diagram / Image Attachment URL',
                  hintText: 'https://...',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
              ),
              const SizedBox(height: BeastSpacing.xl),
              BeastPrimaryButton(
                label: 'Send Question to Faculty',
                icon: Icons.send_rounded,
                isLoading: isSubmitting,
                onPressed: () async {
                  final title = titleController.text.trim();
                  final text = noteController.text.trim();
                  final img = imageUrlController.text.trim();

                  if (title.isEmpty || text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter both title and description.')),
                    );
                    return;
                  }

                  setModalState(() => isSubmitting = true);
                  final provider = Provider.of<StudentProvider>(context, listen: false);
                  final ok = await provider.askDoubt(
                    subjectId: selectedSubjectId,
                    title: title,
                    questionText: text,
                    imageUrl: img.isNotEmpty ? img : null,
                  );

                  if (mounted) {
                    Navigator.pop(ctx);
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Doubt submitted to faculty successfully.'),
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
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final openDoubts = student.doubts.where((d) => d.status.toUpperCase() != 'RESOLVED').toList();
    final resolvedDoubts = student.doubts.where((d) => d.status.toUpperCase() == 'RESOLVED').toList();

    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Academic Doubts Desk'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: BeastColors.dark900,
          unselectedLabelColor: BeastColors.textSecondary,
          indicatorColor: BeastColors.brandPrimary,
          indicatorWeight: 2.5,
          tabs: [
            Tab(text: 'Pending Clarification (${openDoubts.length})'),
            Tab(text: 'Resolved (${resolvedDoubts.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDoubtDialog,
        backgroundColor: BeastColors.brandPrimary,
        foregroundColor: BeastColors.white,
        icon: const Icon(Icons.help_outline_rounded, size: 20),
        label: const Text('Ask a Doubt'),
      ),
      body: student.isLoading && student.doubts.isEmpty
          ? const BeastLoadingState(message: 'Loading doubts...')
          : student.errorMessage != null && student.doubts.isEmpty
              ? BeastErrorState(
                  message: student.errorMessage!,
                  onRetry: () => student.fetchDoubts(),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDoubtsTab(openDoubts, isDesktop, false),
                    _buildDoubtsTab(resolvedDoubts, isDesktop, true),
                  ],
                ),
    );
  }

  Widget _buildDoubtsTab(List<DoubtModel> doubts, bool isDesktop, bool isResolved) {
    if (doubts.isEmpty) {
      return BeastEmptyState(
        icon: Icons.question_answer_outlined,
        title: isResolved ? 'No Resolved Doubts' : 'No Open Questions',
        message: isResolved
            ? 'Resolved academic questions will be archived here for reference.'
            : 'You have no pending questions. Tap "Ask a Doubt" to consult faculty.',
      );
    }

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: ListView.separated(
              padding: const EdgeInsets.all(BeastSpacing.lg),
              itemCount: doubts.length,
              separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
              itemBuilder: (ctx, i) {
                final d = doubts[i];
                final isSel = _selectedDoubt?.id == d.id;
                return BeastCard(
                  borderColor: isSel ? BeastColors.brandPrimary : BeastColors.borderSubtle,
                  backgroundColor: isSel ? BeastColors.surfaceWarm.withValues(alpha: 0.3) : BeastColors.white,
                  onTap: () => setState(() => _selectedDoubt = d),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(d.subjectName ?? 'Subject', style: BeastTypography.caption),
                          BeastStatusBadge(status: d.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(d.title, style: BeastTypography.bodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        d.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BeastTypography.caption,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const VerticalDivider(width: 1, color: BeastColors.borderSubtle),
          Expanded(
            flex: 6,
            child: _selectedDoubt != null
                ? _buildDoubtDetailView(_selectedDoubt!)
                : const Center(
                    child: Text('Select a doubt to view faculty discussion', style: TextStyle(color: BeastColors.textMuted)),
                  ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => Provider.of<StudentProvider>(context, listen: false).fetchDoubts(),
      color: BeastColors.brandPrimary,
      child: ListView.separated(
        padding: const EdgeInsets.only(left: BeastSpacing.lg, right: BeastSpacing.lg, top: BeastSpacing.lg, bottom: 80),
        itemCount: doubts.length,
        separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
        itemBuilder: (ctx, i) => _buildDoubtCard(doubts[i]),
      ),
    );
  }

  Widget _buildDoubtCard(DoubtModel d) {
    return BeastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: BeastColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(BeastRadius.xs),
                ),
                child: Text(
                  d.subjectName ?? 'Subject',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: BeastColors.dark900),
                ),
              ),
              BeastStatusBadge(status: d.status),
            ],
          ),
          const SizedBox(height: BeastSpacing.md),
          Text(d.title, style: BeastTypography.title),
          const SizedBox(height: 4),
          Text(d.note, style: BeastTypography.body.copyWith(color: BeastColors.textSecondary)),
          if (d.responseCount > 0) ...[
            const SizedBox(height: BeastSpacing.md),
            const Divider(color: BeastColors.borderSubtle),
            const SizedBox(height: BeastSpacing.sm),
            Container(
              padding: const EdgeInsets.all(BeastSpacing.md),
              decoration: BoxDecoration(
                color: BeastColors.neutral100,
                borderRadius: BorderRadius.circular(BeastRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.forum_outlined, size: 16, color: BeastColors.brandPrimary),
                  const SizedBox(width: 8),
                  Text('${d.responseCount} Faculty Response(s)', style: BeastTypography.caption.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
          if (d.status.toUpperCase() != 'RESOLVED') ...[
            const SizedBox(height: BeastSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Mark as Resolved'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(140, 36),
                ),
                onPressed: () async {
                  final provider = Provider.of<StudentProvider>(context, listen: false);
                  await provider.resolveDoubt(d.id, true);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Doubt marked as resolved.')),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDoubtDetailView(DoubtModel d) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(BeastSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BeastBadge(
                label: d.subjectName ?? 'Subject',
                backgroundColor: BeastColors.surfaceWarm,
                textColor: BeastColors.dark900,
              ),
              BeastStatusBadge(status: d.status),
            ],
          ),
          const SizedBox(height: BeastSpacing.md),
          Text(d.title, style: BeastTypography.headline),
          const SizedBox(height: BeastSpacing.sm),
          Text(d.note, style: BeastTypography.body),
          const SizedBox(height: BeastSpacing.xl),
          const BeastSectionHeader(title: 'Faculty Responses'),
          const Divider(color: BeastColors.borderSubtle),
          if (d.responseCount == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No response yet from faculty. You will be notified once answered.', style: TextStyle(color: BeastColors.textMuted)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: BeastCard(
                child: Row(
                  children: [
                    const Icon(Icons.forum_outlined, color: BeastColors.brandPrimary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${d.responseCount} Faculty Response(s)', style: BeastTypography.bodyMedium),
                          Text('Status: ${d.status.toUpperCase()}', style: BeastTypography.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (d.status.toUpperCase() != 'RESOLVED') ...[
            const SizedBox(height: BeastSpacing.xl),
            BeastPrimaryButton(
              label: 'Mark as Resolved',
              icon: Icons.check_circle_rounded,
              onPressed: () async {
                final provider = Provider.of<StudentProvider>(context, listen: false);
                await provider.resolveDoubt(d.id, true);
                if (context.mounted) {
                  setState(() => _selectedDoubt = null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Doubt marked as resolved.')),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
