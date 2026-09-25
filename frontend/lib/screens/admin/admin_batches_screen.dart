import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/app_card.dart';

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
          title: const Text('Create New Batch'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Batch Name', hintText: 'e.g. PCM-2027-C'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedClassId,
                decoration: const InputDecoration(labelText: 'Parent Class'),
                items: admin.classes.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.stream})'))).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedClassId = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max Capacity'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
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
                      SnackBar(content: Text(ok ? 'Batch created!' : 'Failed to create batch.')),
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
      appBar: AppBar(
        title: const Text('Academic Batches & Curriculum'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Batches (${admin.batches.length})'),
            Tab(text: 'Classes (${admin.classes.length})'),
            Tab(text: 'Subjects (${admin.subjects.length})'),
          ],
        ),
      ),
      body: admin.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: BATCHES
                RefreshIndicator(
                  onRefresh: () => admin.fetchAcademics(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: admin.batches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final b = admin.batches[i];
                      return AppCard(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.group_work, color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  Text(
                                    '${b.className ?? "Class"} (${b.classStream ?? "Stream"}) • ${b.studentCount} Students Enrolled',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  Text(
                                    'Capacity: ${b.studentCount} / ${b.maxCapacity}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
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
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: admin.classes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final c = admin.classes[i];
                      return AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(4)),
                                  child: Text(c.stream ?? 'General', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            if (c.description != null && c.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(c.description!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // TAB 3: SUBJECTS
                RefreshIndicator(
                  onRefresh: () => admin.fetchAcademics(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: admin.subjects.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final s = admin.subjects[i];
                      return AppCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                Text('Class: ${s.className ?? "Class 12"}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(8)),
                              child: Text(s.code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primary)),
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Batch', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
