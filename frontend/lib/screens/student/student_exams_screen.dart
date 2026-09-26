import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/beast_tokens.dart';
import '../../providers/student_provider.dart';
import '../../widgets/beast_components.dart';

class StudentExamsScreen extends StatefulWidget {
  const StudentExamsScreen({super.key});

  @override
  State<StudentExamsScreen> createState() => _StudentExamsScreenState();
}

class _StudentExamsScreenState extends State<StudentExamsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentProvider>(context, listen: false).fetchExamsAndResults();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final student = Provider.of<StudentProvider>(context);
    final summary = student.resultsSummary;

    return Scaffold(
      backgroundColor: BeastColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Examinations & Results'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: BeastColors.dark900,
          unselectedLabelColor: BeastColors.textSecondary,
          indicatorColor: BeastColors.brandPrimary,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'Academic Results'),
            Tab(text: 'Exam Schedules'),
          ],
        ),
      ),
      body: student.isLoading && student.exams.isEmpty && student.results.isEmpty
          ? const BeastLoadingState(message: 'Loading examination records...')
          : student.errorMessage != null && student.exams.isEmpty && student.results.isEmpty
              ? BeastErrorState(
                  message: student.errorMessage!,
                  onRetry: () => student.fetchExamsAndResults(),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildResultsTab(student, summary),
                    _buildSchedulesTab(student),
                  ],
                ),
    );
  }

  Widget _buildResultsTab(StudentProvider student, Map<String, dynamic>? summary) {
    return RefreshIndicator(
      onRefresh: () => student.fetchExamsAndResults(),
      color: BeastColors.brandPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(BeastSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (summary != null) ...[
                  BeastCard(
                    padding: const EdgeInsets.all(BeastSpacing.xl),
                    child: Column(
                      children: [
                        Text(
                          'CUMULATIVE PERFORMANCE',
                          style: BeastTypography.label.copyWith(letterSpacing: 1.0),
                        ),
                        const SizedBox(height: BeastSpacing.md),
                        Text(
                          '${summary['cumulativePercentage'] ?? 0}%',
                          style: BeastTypography.metricLarge,
                        ),
                        const SizedBox(height: BeastSpacing.sm),
                        BeastBadge(
                          label: 'Overall Grade: ${summary['overallGrade'] ?? "N/A"}',
                          backgroundColor: BeastColors.peach200,
                          textColor: BeastColors.dark900,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Total Exams Evaluated: ${summary['totalExams'] ?? 0}',
                          style: BeastTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: BeastSpacing.xl),
                ],
                const BeastSectionHeader(title: 'Published Report Cards'),
                const Divider(color: BeastColors.borderSubtle),
                if (student.results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: BeastSpacing.xxl),
                    child: BeastEmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: 'No Examination Results',
                      message: 'Evaluated examination scorecards and faculty feedback will be published here.',
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: student.results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
                    itemBuilder: (ctx, i) {
                      final r = student.results[i];
                      return BeastCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(r.examTitle ?? 'Assessment', style: BeastTypography.title),
                                BeastBadge(
                                  label: 'Grade ${r.grade ?? "-"}',
                                  backgroundColor: BeastColors.surfaceWarm,
                                  textColor: BeastColors.dark900,
                                ),
                              ],
                            ),
                            const SizedBox(height: BeastSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  r.subjectName ?? 'Subject',
                                  style: BeastTypography.body.copyWith(color: BeastColors.textSecondary),
                                ),
                                Text(
                                  '${r.marksObtained.toStringAsFixed(0)} / ${r.maxMarks.toStringAsFixed(0)} (${r.percentage.toStringAsFixed(1)}%)',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (r.percentage / 100).clamp(0.0, 1.0),
                                backgroundColor: BeastColors.neutral100,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  r.percentage >= 40 ? BeastColors.success : BeastColors.danger,
                                ),
                                minHeight: 6,
                              ),
                            ),
                            if (r.feedback != null && r.feedback!.isNotEmpty) ...[
                              const SizedBox(height: BeastSpacing.md),
                              Text(
                                'Teacher Remarks: ${r.feedback}',
                                style: BeastTypography.caption.copyWith(fontStyle: FontStyle.italic),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSchedulesTab(StudentProvider student) {
    final exams = student.exams;

    return RefreshIndicator(
      onRefresh: () => student.fetchExamsAndResults(),
      color: BeastColors.brandPrimary,
      child: exams.isEmpty
          ? const BeastEmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'No Upcoming Exams',
              message: 'Institutional term tests, unit assessments, and mock exams will appear here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(BeastSpacing.lg),
              itemCount: exams.length,
              separatorBuilder: (_, __) => const SizedBox(height: BeastSpacing.md),
              itemBuilder: (ctx, i) {
                final e = exams[i];
                return BeastCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.title, style: BeastTypography.title),
                          BeastBadge(
                            label: e.examType,
                            backgroundColor: BeastColors.peach200,
                            textColor: BeastColors.dark900,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scheduled: ${e.startDate} to ${e.endDate}',
                        style: BeastTypography.caption,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
