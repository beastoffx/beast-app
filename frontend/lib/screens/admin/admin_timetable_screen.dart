import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/admin_provider.dart';
import '../../core/services/api_service.dart';
import '../../widgets/beast_components.dart';

class AdminTimetableScreen extends StatefulWidget {
  const AdminTimetableScreen({super.key});

  @override
  State<AdminTimetableScreen> createState() => _AdminTimetableScreenState();
}

class _AdminTimetableScreenState extends State<AdminTimetableScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  List<dynamic> _slots = [];
  int _selectedDay = 1; // 1 = Monday

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

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
    int dayOfWeek = _selectedDay;
    final startController = TextEditingController(text: '12:00');
    final endController = TextEditingController(text: '13:30');
    final roomController = TextEditingController(text: 'Hall Alpha');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Schedule Lecture Slot', style: BeastTypography.h3),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: dayOfWeek,
                  decoration: const InputDecoration(labelText: 'Day of Week', border: OutlineInputBorder()),
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
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedBatchId,
                  decoration: const InputDecoration(labelText: 'Target Batch', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'batch-pcm-2027-a', child: Text('PCM-2027-A (Class 12)')),
                    DropdownMenuItem(value: 'batch-pcb-2027-b', child: Text('PCB-2027-B (Class 12)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedBatchId = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedSubjectId,
                  decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'sub-phy-12', child: Text('Physics (PHY-12)')),
                    DropdownMenuItem(value: 'sub-chm-12', child: Text('Chemistry (CHM-12)')),
                    DropdownMenuItem(value: 'sub-mth-12', child: Text('Mathematics (MTH-12)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedSubjectId = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startController,
                        decoration: const InputDecoration(labelText: 'Start (HH:MM)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: endController,
                        decoration: const InputDecoration(labelText: 'End (HH:MM)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomController,
                  decoration: const InputDecoration(labelText: 'Classroom / Hall', border: OutlineInputBorder()),
                ),
              ],
            ),
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
                      const SnackBar(content: Text('Lecture slot scheduled successfully!'), backgroundColor: BeastColors.success),
                    );
                    _loadTimetable();
                  } else {
                    showDialog(
                      context: context,
                      builder: (alertCtx) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: BeastColors.error),
                            SizedBox(width: 8),
                            Text('Scheduling Conflict'),
                          ],
                        ),
                        content: Text(res.error ?? 'Schedule collision detected. Double-booking prevented.'),
                        actions: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: BeastColors.dark900),
                            onPressed: () => Navigator.pop(alertCtx),
                            child: const Text('OK'),
                          ),
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
    // Filter slots by selected day if slots include day_of_week
    final daySlots = _slots.where((s) {
      final dow = s['day_of_week'];
      return dow == null || dow == _selectedDay;
    }).toList();

    return Scaffold(
      backgroundColor: BeastColors.surfaceNeutral,
      appBar: AppBar(
        title: Text('Timetable & Schedule Matrix', style: BeastTypography.h3),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: BeastColors.dark900), onPressed: _loadTimetable),
        ],
      ),
      body: Column(
        children: [
          // Day selector chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: BeastSpacing.lg, vertical: BeastSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_days.length, (idx) {
                final dayNum = idx + 1;
                final isSelected = _selectedDay == dayNum;
                return ChoiceChip(
                  label: Text(_days[idx]),
                  selected: isSelected,
                  selectedColor: BeastColors.peach200,
                  backgroundColor: BeastColors.neutral100,
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? BeastColors.dark900 : BeastColors.textSecondary,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedDay = dayNum);
                  },
                );
              }),
            ),
          ),
          const Divider(height: 1, color: BeastColors.borderSubtle),

          // Slots list
          Expanded(
            child: _loading
                ? const Center(child: BeastLoadingState(message: 'Loading timetable matrix...'))
                : daySlots.isEmpty
                    ? BeastEmptyState(
                        icon: Icons.calendar_month_outlined,
                        title: 'No Slots for ${_days[_selectedDay - 1]}',
                        subtitle: 'Schedule class lectures and assign classrooms without double-booking collisions.',
                        buttonLabel: 'Schedule Lecture',
                        onButtonPressed: _showScheduleDialog,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTimetable,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(BeastSpacing.lg),
                          itemCount: daySlots.length,
                          separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                          itemBuilder: (ctx, i) {
                            final s = daySlots[i];
                            return BeastCard(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: BeastColors.peach100,
                                      borderRadius: BorderRadius.circular(BeastRadius.sm),
                                      border: Border.all(color: BeastColors.peach300),
                                    ),
                                    child: Column(
                                      children: [
                                        Text('${s['start_time']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: BeastColors.dark900)),
                                        const Text('to', style: TextStyle(fontSize: 10, color: BeastColors.textMuted)),
                                        Text('${s['end_time']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: BeastColors.dark900)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${s['subject_name'] ?? 'Class Slot'} • Batch ${s['batch_name'] ?? 'Default'}',
                                          style: BeastTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline, size: 14, color: BeastColors.textMuted),
                                            const SizedBox(width: 4),
                                            Text(s['teacher_name'] ?? 'Faculty', style: BeastTypography.caption),
                                            const SizedBox(width: 12),
                                            const Icon(Icons.meeting_room_outlined, size: 14, color: BeastColors.textMuted),
                                            const SizedBox(width: 4),
                                            Text(s['room_number'] ?? 'Hall', style: BeastTypography.caption),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  BeastBadge(
                                    label: s['room_number'] ?? 'Room',
                                    variant: BeastBadgeVariant.peach,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showScheduleDialog,
        backgroundColor: BeastColors.dark900,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Schedule Slot', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
