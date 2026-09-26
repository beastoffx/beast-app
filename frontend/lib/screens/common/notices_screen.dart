import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/beast_components.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentProvider>(context, listen: false).fetchNotices();
    });
  }

  void _showPublishNoticeDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String category = 'academic';
    String priority = 'medium';
    bool isPinned = false;

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
                  Text('Publish Institutional Notice', style: BeastTypography.h3),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Notice Title',
                  hintText: 'e.g. Schedule Revision for Term Mock',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'academic', child: Text('Academic')),
                  DropdownMenuItem(value: 'exam', child: Text('Examination')),
                  DropdownMenuItem(value: 'class', child: Text('Class / Batch')),
                  DropdownMenuItem(value: 'holiday', child: Text('Holiday')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                  DropdownMenuItem(value: 'general', child: Text('General')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => category = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Detailed Announcement', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: isPinned,
                    activeColor: BeastColors.dark900,
                    onChanged: (v) => setModalState(() => isPinned = v ?? false),
                  ),
                  Text('Pin Notice to Top of Notice Board', style: BeastTypography.bodyMedium),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: BeastColors.dark900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final title = titleController.text.trim();
                  final desc = descriptionController.text.trim();

                  if (title.isEmpty || desc.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill title and description.')),
                    );
                    return;
                  }

                  final admin = Provider.of<AdminProvider>(context, listen: false);
                  final ok = await admin.publishNotice(
                    title: title,
                    description: desc,
                    category: category,
                    priority: category == 'urgent' ? 'urgent' : priority,
                    isPinned: isPinned,
                  );

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Notice published successfully!' : 'Failed to publish notice.'),
                        backgroundColor: ok ? BeastColors.success : BeastColors.error,
                      ),
                    );
                    Provider.of<StudentProvider>(context, listen: false).fetchNotices();
                  }
                },
                child: const Text('Publish Announcement', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final student = Provider.of<StudentProvider>(context);

    final filtered = student.notices.where((n) {
      if (_selectedCategory == 'all') return true;
      return n.category == _selectedCategory;
    }).toList();

    return Scaffold(
      backgroundColor: BeastColors.surfaceNeutral,
      appBar: AppBar(
        title: Text('Institutional Notice Board', style: BeastTypography.h3),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: BeastColors.dark900),
            onPressed: () => student.fetchNotices(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: BeastSpacing.lg, vertical: BeastSpacing.sm),
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All Notices'),
                  const SizedBox(width: 8),
                  _buildFilterChip('exam', 'Examinations'),
                  const SizedBox(width: 8),
                  _buildFilterChip('academic', 'Academics'),
                  const SizedBox(width: 8),
                  _buildFilterChip('holiday', 'Holidays'),
                  const SizedBox(width: 8),
                  _buildFilterChip('urgent', 'Urgent Alerts'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: BeastColors.borderSubtle),

          Expanded(
            child: student.isLoading
                ? const Center(child: BeastLoadingState(message: 'Loading institutional notices...'))
                : filtered.isEmpty
                    ? BeastEmptyState(
                        icon: Icons.campaign_outlined,
                        title: 'No Notices in this category',
                        subtitle: 'Institutional announcements and faculty updates will appear here.',
                      )
                    : RefreshIndicator(
                        onRefresh: () => student.fetchNotices(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(BeastSpacing.lg),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                          itemBuilder: (ctx, i) {
                            final n = filtered[i];
                            final isUrgent = n.isUrgent;

                            return BeastCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (n.isPinned) ...[
                                        const Icon(Icons.push_pin, size: 16, color: BeastColors.dark900),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      BeastBadge(
                                        label: n.category.toUpperCase(),
                                        variant: isUrgent ? BeastBadgeVariant.warning : BeastBadgeVariant.peach,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    n.description,
                                    style: BeastTypography.bodyMedium.copyWith(color: BeastColors.textSecondary, height: 1.4),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, size: 12, color: BeastColors.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Published: ${n.publishDate}${n.authorName != null ? " • Author: ${n.authorName}" : ""}',
                                        style: BeastTypography.caption.copyWith(color: BeastColors.textMuted),
                                      ),
                                    ],
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
      floatingActionButton: (auth.isAdmin || auth.isTeacher)
          ? FloatingActionButton.extended(
              onPressed: _showPublishNoticeDialog,
              backgroundColor: BeastColors.dark900,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.post_add),
              label: const Text('Publish Notice', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedCategory == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: BeastColors.peach200,
      backgroundColor: BeastColors.neutral100,
      onSelected: (_) => setState(() => _selectedCategory = key),
      labelStyle: TextStyle(
        color: isSelected ? BeastColors.dark900 : BeastColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}
