import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/teacher_provider.dart';
import '../../widgets/beast_components.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  String _selectedBatchId = 'batch-pcm-2027-a';
  String _selectedSubjectId = 'sub-phy-12';
  DateTime _selectedDate = DateTime.now();
  Map<String, String> _statuses = {};
  Map<String, String> _remarks = {};
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
        final stuId = s['student_id']?.toString() ?? '';
        newStatuses[stuId] = s['status'] ?? 'present';
        newRemarks[stuId] = s['remarks'] ?? '';
      }
      setState(() {
        _statuses = newStatuses;
        _remarks = newRemarks;
      });
    });
  }

  void _confirmMarkAll(String status, String label) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeastRadius.md)),
        backgroundColor: BeastColors.white,
        title: Text('Mark All $label?', style: BeastTypography.title),
        content: Text(
          'This will set every enrolled student in this batch to "$label".',
          style: BeastTypography.body.copyWith(color: BeastColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: BeastColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final updated = <String, String>{};
              _statuses.forEach((key, _) => updated[key] = status);
              setState(() => _statuses = updated);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BeastColors.brandPrimary,
              foregroundColor: BeastColors.white,
            ),
            child: Text('Confirm $label'),
          ),
        ],
      ),
    );
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
          content: Text(ok ? 'Attendance for ${records.length} students recorded successfully!' : 'Failed to save attendance.'),
          backgroundColor: ok ? BeastColors.success : BeastColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacher = Provider.of<TeacherProvider>(context);
    final sheet = teacher.attendanceSheet;
    final dateDisplay = DateFormat('EEE, dd MMM yyyy').format(_selectedDate);

    int presentCount = 0;
    int absentCount = 0;
    int lateCount = 0;
    _statuses.forEach((_, st) {
      if (st == 'present') presentCount++;
      else if (st == 'absent') absentCount++;
      else if (st == 'late') lateCount++;
    });

    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Batch Roll-Call'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload Roster',
            onPressed: _loadSheet,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(BeastSpacing.lg),
        decoration: BoxDecoration(
          color: BeastColors.white,
          border: const Border(top: BorderSide(color: BeastColors.borderSubtle)),
          boxShadow: BeastShadows.card,
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'P: $presentCount  •  A: $absentCount  •  L: $lateCount',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: BeastColors.dark900),
                    ),
                    Text(
                      'Total: ${sheet.length} students',
                      style: BeastTypography.caption,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _saving ? null : _handleSave,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(_saving ? 'Saving...' : 'Save Attendance'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BeastColors.brandPrimary,
                  foregroundColor: BeastColors.white,
                  minimumSize: const Size(160, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BeastRadius.sm)),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Header Bar
          Container(
            color: BeastColors.white,
            padding: const EdgeInsets.symmetric(horizontal: BeastSpacing.lg, vertical: BeastSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedBatchId,
                        decoration: const InputDecoration(labelText: 'Batch', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        items: const [
                          DropdownMenuItem(value: 'batch-pcm-2027-a', child: Text('Class 12 - PCM Batch A')),
                          DropdownMenuItem(value: 'batch-pcb-2027-a', child: Text('Class 12 - PCB Batch A')),
                          DropdownMenuItem(value: 'batch-jee-adv-2027', child: Text('JEE Advanced Target')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedBatchId = val);
                            _loadSheet();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: BeastSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSubjectId,
                        decoration: const InputDecoration(labelText: 'Subject', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        items: const [
                          DropdownMenuItem(value: 'sub-phy-12', child: Text('Physics')),
                          DropdownMenuItem(value: 'sub-chm-12', child: Text('Chemistry')),
                          DropdownMenuItem(value: 'sub-mth-12', child: Text('Mathematics')),
                          DropdownMenuItem(value: 'sub-bio-12', child: Text('Biology')),
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
                const SizedBox(height: BeastSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime.now().add(const Duration(days: 7)),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                          _loadSheet();
                        }
                      },
                      borderRadius: BorderRadius.circular(BeastRadius.xs),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 16, color: BeastColors.dark900),
                            const SizedBox(width: 6),
                            Text(dateDisplay, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 16),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => _confirmMarkAll('present', 'Present'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(80, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            side: const BorderSide(color: BeastColors.success),
                            foregroundColor: BeastColors.success,
                          ),
                          child: const Text('All Present', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: () => _confirmMarkAll('absent', 'Absent'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(80, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            side: const BorderSide(color: BeastColors.danger),
                            foregroundColor: BeastColors.danger,
                          ),
                          child: const Text('All Absent', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: BeastColors.borderSubtle, height: 1),

          Expanded(
            child: teacher.isLoading
                ? const BeastLoadingState(message: 'Loading student roster...')
                : sheet.isEmpty
                    ? const BeastEmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'No Students in Batch',
                        message: 'No active student enrollments found in this batch.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(
                          left: BeastSpacing.lg,
                          right: BeastSpacing.lg,
                          top: BeastSpacing.md,
                          bottom: BeastSpacing.xxl,
                        ),
                        itemCount: sheet.length,
                        separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.sm),
                        itemBuilder: (ctx, i) {
                          final student = sheet[i];
                          final stuId = student['student_id']?.toString() ?? '';
                          final name = student['name'] ?? 'Student';
                          final rollNo = student['roll_number'] ?? student['enrollment_number'] ?? '${i + 1}';
                          final currentStatus = _statuses[stuId] ?? 'present';

                          return BeastCard(
                            padding: const EdgeInsets.symmetric(horizontal: BeastSpacing.md, vertical: BeastSpacing.sm),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: BeastColors.neutral100,
                                    borderRadius: BorderRadius.circular(BeastRadius.xs),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$rollNo',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: BeastSpacing.md),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: BeastTypography.bodyMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _buildStatusSegment(stuId, currentStatus),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSegment(String stuId, String currentStatus) {
    return Container(
      decoration: BoxDecoration(
        color: BeastColors.neutral100,
        borderRadius: BorderRadius.circular(BeastRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segmentBtn(stuId, 'present', 'P', currentStatus == 'present', BeastColors.success),
          _segmentBtn(stuId, 'late', 'L', currentStatus == 'late', BeastColors.warning),
          _segmentBtn(stuId, 'absent', 'A', currentStatus == 'absent', BeastColors.danger),
        ],
      ),
    );
  }

  Widget _segmentBtn(String stuId, String statusValue, String label, bool isSelected, Color activeColor) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _statuses[stuId] = statusValue;
        });
      },
      child: Container(
        width: 38,
        height: 34,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(BeastRadius.sm),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isSelected ? BeastColors.white : BeastColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
