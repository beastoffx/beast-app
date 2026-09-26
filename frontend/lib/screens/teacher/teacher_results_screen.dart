import 'package:flutter/material.dart';
import '../../core/theme/beast_tokens.dart';
import '../../core/services/api_service.dart';
import '../../widgets/beast_components.dart';

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
        final stuId = s['student_id']?.toString() ?? '';
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
      final stuId = s['student_id']?.toString() ?? '';
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
          backgroundColor: res.success ? BeastColors.success : BeastColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (res.success) {
        _loadResultsSheet();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxMarks = _subjectInfo?['max_marks'] ?? 100;
    final subjectName = _subjectInfo?['subject_name'] ?? 'Physics (PHY-12)';
    final examName = _subjectInfo?['exam_name'] ?? 'Mid-Term Assessment 2026';

    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Examination Scoring Studio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadResultsSheet,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ${_students.length} students enrolled',
                style: BeastTypography.bodyMedium,
              ),
              BeastPrimaryButton(
                label: _saving ? 'Publishing...' : 'Publish Scores',
                icon: Icons.check_circle_rounded,
                isLoading: _saving,
                onPressed: _saveResults,
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const BeastLoadingState(message: 'Loading exam scoring roster...')
          : Column(
              children: [
                // Info Banner
                Container(
                  color: BeastColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: BeastSpacing.lg, vertical: BeastSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(BeastSpacing.md),
                        decoration: BoxDecoration(
                          color: BeastColors.surfaceWarm,
                          borderRadius: BorderRadius.circular(BeastRadius.sm),
                        ),
                        child: const Icon(Icons.grade_outlined, color: BeastColors.dark900, size: 24),
                      ),
                      const SizedBox(width: BeastSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(examName, style: BeastTypography.title.copyWith(fontSize: 16)),
                            Text('$subjectName • Max Marks: $maxMarks', style: BeastTypography.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: BeastColors.borderSubtle, height: 1),

                Expanded(
                  child: _students.isEmpty
                      ? const BeastEmptyState(
                          icon: Icons.assignment_outlined,
                          title: 'No Students Enrolled',
                          message: 'No enrolled students were found for this examination subject.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(
                            left: BeastSpacing.lg,
                            right: BeastSpacing.lg,
                            top: BeastSpacing.md,
                            bottom: 80,
                          ),
                          itemCount: _students.length,
                          separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.sm),
                          itemBuilder: (ctx, i) {
                            final s = _students[i];
                            final stuId = s['student_id']?.toString() ?? '';
                            final name = s['name'] ?? 'Student';
                            final rollNo = s['roll_number'] ?? '${i + 1}';

                            return BeastCard(
                              padding: const EdgeInsets.all(BeastSpacing.md),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
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
                                    flex: 3,
                                    child: Text(name, style: BeastTypography.bodyMedium),
                                  ),
                                  const SizedBox(width: BeastSpacing.md),
                                  SizedBox(
                                    width: 80,
                                    child: TextField(
                                      controller: _marksControllers[stuId],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        hintText: '0 - $maxMarks',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: BeastSpacing.md),
                                  Expanded(
                                    flex: 4,
                                    child: TextField(
                                      controller: _feedbackControllers[stuId],
                                      decoration: const InputDecoration(
                                        hintText: 'Remarks / Feedback',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
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
    );
  }
}
