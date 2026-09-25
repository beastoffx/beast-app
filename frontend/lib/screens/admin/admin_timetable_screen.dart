import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/admin_provider.dart';
import '../../core/services/api_service.dart';
import '../../widgets/app_card.dart';

class AdminTimetableScreen extends StatefulWidget {
  const AdminTimetableScreen({super.key});

  @override
  State<AdminTimetableScreen> createState() => _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends State<AdminTimetableScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<dynamic> _slots = [];

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    setState(() => _loading = true);
    final res = await _api.get('/api/timetable/batch/batch-pcm-2027-a');
    if (res.success && res.data != null) {
      setState(() {
        _slots = res.data as List? ?? [];
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _showScheduleDialog() {
    String selectedBatchId = 'batch-pcm-2027-a';
    String selectedSubjectId = 'sub-phy-12';
    String selectedTeacherId = 'user-teacher-phy';
    int dayOfWeek = 1;
    final startController = TextEditingController(text: '12:00');
    final endController = TextEditingController(text: '13:30');
    final roomController = TextEditingController(text: 'Hall Alpha');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Schedule Lecture Slot'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: dayOfWeek,
                  decoration: const InputDecoration(labelText: 'Day of Week'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Monday')),
                    DropdownMenuItem(value: 2, child: Text('Tuesday')),
                    DropdownMenuItem(value: 3, child: Text('Wednesday')),
                    DropdownMenuItem(value: 4, child: Text('Thursday')),
                    DropdownMenuItem(value: 5, child: Text('Friday')),
                    DropdownMenuItem(value: 6, child: Text('Saturday')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => dayOfWeek = val);
                  },
                ),
                const SizedBox(height: 10),
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
                    DropdownMenuItem(value: 'sub-mth-12', child: Text('Mathematics (MTH-12)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedSubjectId = val);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startController,
                        decoration: const InputDecoration(labelText: 'Start (HH:MM)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: endController,
                        decoration: const InputDecoration(labelText: 'End (HH:MM)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roomController,
                  decoration: const InputDecoration(labelText: 'Classroom / Hall'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final admin = Provider.of<AdminProvider>(context, listen: false);
                final res = await admin.scheduleSlot(
                  batchId: selectedBatchId,
                  subjectId: selectedSubjectId,
                  teacherId: selectedTeacherId,
                  dayOfWeek: dayOfWeek,
                  startTime: startController.text.trim(),
                  endTime: endController.text.trim(),
                  roomNumber: roomController.text.trim(),
                );

                if (mounted) {
                  Navigator.pop(ctx);
                  if (res.success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lecture slot scheduled successfully!'), backgroundColor: AppColors.success),
                    );
                    _loadTimetable();
                  } else {
                    // Double-booking or collision error
                    showDialog(
                      context: context,
                      builder: (alertCtx) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Scheduling Conflict'),
                          ],
                        ),
                        content: Text(res.error ?? 'Schedule collision detected. Double-booking prevented.'),
                        actions: [
                          ElevatedButton(onPressed: () => Navigator.pop(alertCtx), child: const Text('OK')),
                        ],
                      ),
                    );
                  }
                }
              },
              child: const Text('Save Slot'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Institutional Timetable & Scheduling'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTimetable),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _slots.isEmpty
              ? EmptyStateView(
                  icon: Icons.calendar_month_outlined,
                  title: 'No Timetable Slots',
                  description: 'Schedule class lectures and assign classrooms without double-booking collisions.',
                  actionLabel: 'Schedule Lecture',
                  onAction: _showScheduleDialog,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _slots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final s = _slots[i];
                    return AppCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              children: [
                                Text('${s['start_time']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary)),
                                const Text('to', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                Text('${s['end_time']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${s['subject_name']} • Batch ${s['batch_name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                Text('Teacher: ${s['teacher_name']} • Room: ${s['room_number']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showScheduleDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Schedule Slot', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
