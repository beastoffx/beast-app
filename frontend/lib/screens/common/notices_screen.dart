import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_card.dart';
import '../../models/material_notice_model.dart';

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
                  const Text('Publish Institutional Notice', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Notice Title', hintText: 'e.g. Schedule Revision for Term Mock'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category'),
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
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Detailed Announcement'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: isPinned,
                    onChanged: (v) => setModalState(() => isPinned = v ?? false),
                  ),
                  const Text('Pin Notice to Top of Notice Board', style: TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
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
                        backgroundColor: ok ? AppColors.success : AppColors.error,
                      ),
                    );
                    Provider.of<StudentProvider>(context, listen: false).fetchNotices();
                  }
                },
                child: const Text('Publish Announcement'),
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
      appBar: AppBar(
        title: const Text('Institutional Notice Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => student.fetchNotices(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          const Divider(height: 1),

          Expanded(
            child: student.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.campaign_outlined,
                        title: 'No Notices in this category',
                        description: 'Institutional announcements and faculty updates will appear here.',
                      )
                    : RefreshIndicator(
                        onRefresh: () => student.fetchNotices(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final n = filtered[i];
                            final isUrgent = n.isUrgent;

                            return AppCard(
                              color: isUrgent ? AppColors.errorLight : AppColors.surface,
                              border: isUrgent ? Border.all(color: AppColors.error.withOpacity(0.4), width: 1.5) : null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (n.isPinned) ...[
                                        const Icon(Icons.push_pin, size: 16, color: AppColors.secondary),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(
                                        child: Text(
                                          n.title,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isUrgent ? AppColors.error : AppColors.surfaceElevated,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          n.category.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isUrgent ? Colors.white : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    n.description,
                                    style: TextStyle(fontSize: 13, color: isUrgent ? AppColors.textPrimary : AppColors.textSecondary, height: 1.4),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Published: ${n.publishDate}${n.authorName != null ? " • Author: ${n.authorName}" : ""}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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
              backgroundColor: AppColors.primary,
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
      onSelected: (_) => setState(() => _selectedCategory = key),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}
