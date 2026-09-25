import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/app_card.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  String _selectedBatchId = 'batch-pcm-2027-a';
  String _selectedSubjectId = 'sub-phy-12';
  DateTime _selectedDate = DateTime.now();
  Map<String, String> _statuses = {}; // student_id -> 'present'|'absent'|'late'|'excused'
  Map<String, String> _remarks = {};  // student_id -> remarks
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSheet();
    });
  }

  void _loadSheet() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final teacher = Provider.of<TeacherProvider>(context, listen: false);
    teacher.fetchAttendanceSheet(_selectedBatchId, _selectedSubjectId, dateStr).then((_) {
      final sheet = teacher.attendanceSheet;
      final newStatuses = <String, String>{};
      final newRemarks = <String, String>{};
      for (var s in sheet) {
        final stuId = s['student_id'];
        newStatuses[stuId] = s['status'] ?? 'present';
        newRemarks[stuId] = s['remarks'] ?? '';
      }
      setState(() {
        _statuses = newStatuses;
        _remarks = newRemarks;
      });
    });
  }

  void _markAll(String status) {
    final updated = <String, String>{};
    _statuses.forEach((key, _) => updated[key] = status);
    setState(() => _statuses = updated);
  }

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final teacher = Provider.of<TeacherProvider>(context, listen: false);

    final records = <Map<String, dynamic>>[];
    _statuses.forEach((studentId, status) {
      records.add({
        'student_id': studentId,
        'status': status,
        'remarks': _remarks[studentId] ?? '',
      });
    });

    final ok = await teacher.saveBatchAttendance(
      _selectedBatchId,
      _selectedSubjectId,
      dateStr,
      records,
    );

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Attendance for ${records.length} students saved successfully!' : 'Failed to save attendance.'),
          backgroundColor: ok ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacher = Provider.of<TeacherProvider>(context);
    final sheet = teacher.attendanceSheet;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Batch Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Selectors Card
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedBatchId,
                        decoration: const InputDecoration(labelText: 'Batch', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        items: const [
                          DropdownMenuItem(value: 'batch-pcm-2027-a', child: Text('PCM-2027-A (Class 12)')),
                          DropdownMenuItem(value: 'batch-pcb-2027-b', child: Text('PCB-2027-B (Class 12)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedBatchId = val);
                            _loadSheet();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSubjectId,
                        decoration: const InputDecoration(labelText: 'Subject', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        items: const [
                          DropdownMenuItem(value: 'sub-phy-12', child: Text('Physics (PHY-12)')),
                          DropdownMenuItem(value: 'sub-chm-12', child: Text('Chemistry (CHM-12)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedSubjectId = val);
                            _loadSheet();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2026, 1, 1),
                          lastDate: DateTime(2027, 12, 31),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                          _loadSheet();
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.event, size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => _markAll('present'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(80, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text('All Present', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: () => _markAll('absent'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(80, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: const Text('All Absent', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Student Attendance List
          Expanded(
            child: teacher.isLoading
                ? const Center(child: CircularProgressIndicator())
                : sheet.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.people_outline,
                        title: 'No Students Enrolled',
                        description: 'There are no active student enrollments found in this batch.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: sheet.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final stu = sheet[i];
                          final stuId = stu['student_id'];
                          final currentStatus = _statuses[stuId] ?? 'present';

                          return AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.primaryLight.withOpacity(0.12),
                                  child: Text(
                                    (stu['student_name'] ?? 'S')[0],
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stu['student_name'] ?? 'Student',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                      Text(
                                        stu['student_id_number'] ?? '',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                // Segmented Attendance Buttons
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildStatusButton(stuId, 'present', 'P', AppColors.success, currentStatus == 'present'),
                                    const SizedBox(width: 6),
                                    _buildStatusButton(stuId, 'late', 'L', AppColors.warning, currentStatus == 'late'),
                                    const SizedBox(width: 6),
                                    _buildStatusButton(stuId, 'absent', 'A', AppColors.error, currentStatus == 'absent'),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Save Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(top: BorderSide(color: AppColors.border)),
            ),
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _handleSave,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_saving ? 'Recording Attendance...' : 'Save & Publish Attendance Record'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String studentId, String status, String label, Color color, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _statuses[studentId] = status;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : color.withOpacity(0.3), width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
