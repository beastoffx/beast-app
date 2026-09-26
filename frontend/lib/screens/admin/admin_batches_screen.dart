import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/beast_components.dart';

class AdminBatchesScreen extends StatefulWidget {
  const AdminBatchesScreen({super.key});

  @override
  State<AdminBatchesScreen> createState() => _AdminBatchesScreenState();
}

class _AdminBatchesScreenState extends State<AdminBatchesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchAcademics();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateBatchDialog() {
    final nameController = TextEditingController();
    final capacityController = TextEditingController(text: '40');
    final admin = Provider.of<AdminProvider>(context, listen: false);
    String selectedClassId = admin.classes.isNotEmpty ? admin.classes.first.id : 'class-12-sci';
    String selectedSessionId = admin.sessions.isNotEmpty ? admin.sessions.first.id : 'session-2026-2027';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Create New Batch', style: BeastTypography.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Batch Name',
                  hintText: 'e.g. PCM-2027-C',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selectedClassId,
                decoration: const InputDecoration(
                  labelText: 'Parent Class',
                  border: OutlineInputBorder(),
                ),
                items: admin.classes
                    .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.stream})')))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedClassId = val);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Capacity',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: BeastColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: BeastColors.dark900,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final ok = await admin.createBatch(
                    name,
                    selectedClassId,
                    selectedSessionId,
                    maxCapacity: int.tryParse(capacityController.text.trim()) ?? 40,
                  );
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? 'Batch created successfully!' : 'Failed to create batch.')),
                    );
                  }
                }
              },
              child: const Text('Create Batch'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      backgroundColor: BeastColors.surfaceNeutral,
      appBar: AppBar(
        title: Text('Academic Structure & Batches', style: BeastTypography.h3),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: BeastColors.dark900,
          unselectedLabelColor: BeastColors.textSecondary,
          indicatorColor: BeastColors.peach400,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Batches (${admin.batches.length})'),
            Tab(text: 'Classes (${admin.classes.length})'),
            Tab(text: 'Subjects (${admin.subjects.length})'),
          ],
        ),
      ),
      body: admin.isLoading
          ? const Center(child: BeastLoadingState(message: 'Loading academic roster...'))
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: BATCHES
                RefreshIndicator(
                  onRefresh: () => admin.fetchAcademics(),
                  child: admin.batches.isEmpty
                      ? const BeastEmptyState(
                          icon: Icons.groups_outlined,
                          title: 'No Batches Found',
                          subtitle: 'Create a new batch using the button below to assign students.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(BeastSpacing.lg),
                          itemCount: admin.batches.length,
                          separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                          itemBuilder: (ctx, i) {
                            final b = admin.batches[i];
                            final cap = b.maxCapacity > 0 ? b.maxCapacity : 40;
                            final ratio = (b.studentCount / cap).clamp(0.0, 1.0);
                            return BeastCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: BeastColors.peach200,
                                          borderRadius: BorderRadius.circular(BeastRadius.sm),
                                        ),
                                        child: const Icon(Icons.group_work, color: BeastColors.dark900, size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(b.name, style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${b.className ?? "Class"} (${b.classStream ?? "Stream"})',
                                              style: BeastTypography.caption,
                                            ),
                                          ],
                                        ),
                                      ),
                                      BeastBadge(
                                        label: '${b.studentCount} / $cap',
                                        variant: ratio >= 0.9 ? BeastBadgeVariant.warning : BeastBadgeVariant.neutral,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 6,
                                      backgroundColor: BeastColors.neutral200,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        ratio >= 0.9 ? BeastColors.warning : BeastColors.peach400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // TAB 2: CLASSES
                RefreshIndicator(
                  onRefresh: () => admin.fetchAcademics(),
                  child: admin.classes.isEmpty
                      ? const BeastEmptyState(
                          icon: Icons.school_outlined,
                          title: 'No Classes Configured',
                          subtitle: 'Academic classes will appear here.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(BeastSpacing.lg),
                          itemCount: admin.classes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                          itemBuilder: (ctx, i) {
                            final c = admin.classes[i];
                            return BeastCard(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name, style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                                      if (c.description != null && c.description!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(c.description!, style: BeastTypography.caption),
                                      ],
                                    ],
                                  ),
                                  BeastBadge(
                                    label: c.stream ?? 'General',
                                    variant: BeastBadgeVariant.peach,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // TAB 3: SUBJECTS
                RefreshIndicator(
                  onRefresh: () => admin.fetchAcademics(),
                  child: admin.subjects.isEmpty
                      ? const BeastEmptyState(
                          icon: Icons.menu_book_outlined,
                          title: 'No Subjects Listed',
                          subtitle: 'Academic subjects will appear here.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(BeastSpacing.lg),
                          itemCount: admin.subjects.length,
                          separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                          itemBuilder: (ctx, i) {
                            final s = admin.subjects[i];
                            return BeastCard(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.name, style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text('Class: ${s.className ?? "Class 12"}', style: BeastTypography.caption),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: BeastColors.neutral100,
                                      borderRadius: BorderRadius.circular(BeastRadius.xs),
                                      border: Border.all(color: BeastColors.borderSubtle),
                                    ),
                                    child: Text(
                                      s.code,
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: BeastColors.dark900),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateBatchDialog,
        backgroundColor: BeastColors.dark900,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Batch', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
