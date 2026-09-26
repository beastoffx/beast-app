import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../widgets/app_card.dart';

class TeacherResultsScreen extends StatefulWidget {
  const TeacherResultsScreen({super.key});

  @override
  State<TeacherResultsScreen> createState() => _TeacherResultsScreenState();
}

class _TeacherResultsScreenState extends State<TeacherResultsScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  final String _selectedExamSubjectId = 'exam-sub-phy-01';
  Map<String, dynamic>? _subjectInfo;
  List<dynamic> _students = [];
  Map<String, TextEditingController> _marksControllers = {};
  Map<String, TextEditingController> _feedbackControllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadResultsSheet();
  }

  Future<void> _loadResultsSheet() async {
    setState(() => _loading = true);
    final res = await _api.get('/api/results/exam-subject/$_selectedExamSubjectId');
    if (res.success && res.data != null) {
      _subjectInfo = res.data['subjectInfo'];
      _students = res.data['students'] as List? ?? [];

      final newMarks = <String, TextEditingController>{};
      final newFeedback = <String, TextEditingController>{};
      for (var s in _students) {
        final stuId = s['student_id'];
        newMarks[stuId] = TextEditingController(text: s['marks_obtained'] != null ? s['marks_obtained'].toString() : '');
        newFeedback[stuId] = TextEditingController(text: s['feedback'] ?? '');
      }

      setState(() {
        _marksControllers = newMarks;
        _feedbackControllers = newFeedback;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveResults() async {
    setState(() => _saving = true);
    final marksData = <Map<String, dynamic>>[];

    for (var s in _students) {
      final stuId = s['student_id'];
      final text = _marksControllers[stuId]?.text.trim() ?? '';
      if (text.isNotEmpty) {
        marksData.add({
          'student_id': stuId,
          'marks_obtained': double.tryParse(text) ?? 0.0,
          'max_marks': _subjectInfo?['max_marks'] ?? 100,
          'feedback': _feedbackControllers[stuId]?.text.trim() ?? '',
        });
      }
    }

    final res = await _api.post('/api/results/batch', {
      'exam_subject_id': _selectedExamSubjectId,
      'marks_data': marksData,
    });

    setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.success ? 'Examination results recorded successfully!' : 'Failed to save results.'),
          backgroundColor: res.success ? AppColors.success : AppColors.error,
        ),
      );
      if (res.success) {
        _loadResultsSheet();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Examination Marks'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Subject Info Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.surface,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.assessment_outlined, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _subjectInfo?['exam_title'] ?? 'Mid-Term Assessment 2026',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            Text(
                              '${_subjectInfo?['subject_name']} (${_subjectInfo?['subject_code']}) • Max Marks: ${_subjectInfo?['max_marks'] ?? 100}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: _students.isEmpty
                      ? const Center(child: Text('No students found for this assessment.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _students.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final stu = _students[i];
                            final stuId = stu['student_id'];
                            return AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        stu['student_name'] ?? 'Student',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                      if (stu['grade'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.successLight,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Grade ${stu['grade']}',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.success),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(stu['student_id_number'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 120,
                                        child: TextField(
                                          controller: _marksControllers[stuId],
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Marks',
                                            hintText: 'e.g. 88.5',
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: _feedbackControllers[stuId],
                                          decoration: const InputDecoration(
                                            labelText: 'Faculty Feedback',
                                            hintText: 'e.g. Excellent mechanics clarity',
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Save Button Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.surface,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveResults,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'Recording Scores...' : 'Save & Publish Examination Marks'),
                  ),
                ),
              ],
            ),
    );
  }
}
